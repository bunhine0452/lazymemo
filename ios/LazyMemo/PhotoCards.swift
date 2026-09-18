import ImageIO
import LazyMemoCore
import SwiftUI
import UIKit

/// 본문이 물고 있는 사진 한 장 — 맥의 `AttachedImage` 와 같은 뜻.
struct AttachedPhoto: Identifiable, Equatable {
    enum State: Equatable {
        case ready(UIImage)
        case downloading
        case missing
    }

    let path: String
    var state: State
    var id: String { path }
    /// 소리로 읽을 이름. 경로 전체는 읽어 봐야 알 수 없다.
    var name: String { (path as NSString).lastPathComponent }
}

/// 본문의 사진 참조를 파일에서 읽는다. iCloud 가 자리만 잡아 둔 것은 청하고 기다린다.
///
/// 화면에 드는 것은 줄인 그림이다 — 원본을 들고 있으면 사진 몇 장에 메모리가
/// 무너진다 (맥의 §11 규칙과 같다). 원본은 펼칠 때만 다시 읽는다 (`PhotoViewer`).
@MainActor @Observable
final class PhotoLoader {
    private(set) var photos: [AttachedPhoto] = []
    private var store: AttachmentStore?

    /// 화면 폭의 두세 배면 충분하다. 픽셀 단위.
    nonisolated static let thumbnailMaxPixel: CGFloat = 900
    /// 내려받기를 기다리는 동안 들여다보는 간격과 상한.
    private static let pollInterval: Duration = .milliseconds(700)
    private static let pollLimit = 60

    func originalURL(for photo: AttachedPhoto) -> URL? { store?.url(for: photo.path) }

    /// 경로가 같으면 다시 읽지 않는다. 취소되면(메모를 닫으면) 기다림도 끝난다.
    func load(paths: [String], store: AttachmentStore) async {
        self.store = store
        guard paths != photos.map(\.path) || photos.contains(where: { $0.state == .downloading }) else { return }
        photos = paths.map { AttachedPhoto(path: $0, state: .downloading) }
        var pending = Set(paths)
        var polls = 0
        while !pending.isEmpty, !Task.isCancelled {
            for path in pending {
                switch store.availability(of: path) {
                case .present:
                    let image = await Self.downsample(store.url(for: path))
                    set(path, image.map { .ready($0) } ?? .missing)
                    pending.remove(path)
                case .missing:
                    set(path, .missing)
                    pending.remove(path)
                case .downloading:
                    continue
                }
            }
            guard !pending.isEmpty else { break }
            polls += 1
            if polls >= Self.pollLimit {
                for path in pending { set(path, .missing) }
                break
            }
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    private func set(_ path: String, _ state: AttachedPhoto.State) {
        guard let index = photos.firstIndex(where: { $0.path == path }) else { return }
        photos[index].state = state
    }

    /// ImageIO 로 줄여서 읽는다 — 원본을 메모리에 올렸다 줄이는 것이 아니라 읽으면서 줄인다.
    nonisolated static func downsample(_ url: URL?, maxPixel: CGFloat = thumbnailMaxPixel) async -> UIImage? {
        guard let url else { return nil }
        return await Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }.value
    }
}

/// 종이 머리의 사진 띠 (MOBILE_DESIGN §5 사진). 한 장이면 전폭, 여럿이면 옆으로 쓸어 넘긴다.
struct PhotoCardsView: View {
    let loader: PhotoLoader
    /// 종이 위에서 사진이 차지할 수 있는 최대 높이.
    var maxHeight: CGFloat = 180
    /// 「사진 떼기」— 본문의 참조를 지운다. 글 칸이 참조를 감추므로(`MachineLines`) 떼는 길은 카드뿐이다.
    var remove: ((AttachedPhoto) -> Void)?

    @State private var opened: AttachedPhoto?
    @State private var page: String?

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(loader.photos) { photo in
                        card(photo)
                            .containerRelativeFrame(.horizontal)
                            .id(photo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollDisabled(loader.photos.count < 2)
            if loader.photos.count > 1 {
                HStack(spacing: 6) {
                    ForEach(loader.photos) { photo in
                        let current = (page ?? loader.photos.first?.id) == photo.id
                        Capsule()
                            .fill(current ? Theme.accentInk : Theme.accentInk.opacity(0.25))
                            .frame(width: current ? 14 : 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .fullScreenCover(item: $opened) { photo in
            PhotoViewer(photo: photo, originalURL: loader.originalURL(for: photo))
        }
    }

    @ViewBuilder
    private func card(_ photo: AttachedPhoto) -> some View {
        switch photo.state {
        case .ready(let image):
            Button { opened = photo } label: {
                Image(uiImage: image)
                    .resizable()
                    // 뚜껑에 걸리면 채워서 자른다 — 종이에 붙인 사진이지 화면 가운데 뜬 그림이 아니다.
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height(of: image))
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Paper.ink.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "사진 \(photo.name)"))
            .accessibilityHint("펼쳐 봅니다")
            .accessibilityIdentifier("photo")
            .contextMenu { removeItem(photo) }
        case .downloading:
            placeholder(String(localized: "iCloud 에서 내려받는 중"), systemImage: "icloud.and.arrow.down", spinning: true)
                .accessibilityIdentifier("photo-downloading")
                .contextMenu { removeItem(photo) }
        case .missing:
            placeholder(String(localized: "아직 없는 사진 — 다른 기기가 올리면 보여요"), systemImage: "photo.badge.exclamationmark")
                .accessibilityIdentifier("photo-missing")
                .contextMenu { removeItem(photo) }
        }
    }

    /// 길게 누르면 — 사진은 카드가 곧 그 사진이니 떼는 것도 여기서. 파일은 남고(휴지통의 규칙과 같다) 참조만 빠진다.
    @ViewBuilder
    private func removeItem(_ photo: AttachedPhoto) -> some View {
        if let remove {
            Button(role: .destructive) { remove(photo) } label: { Label("사진 떼기", systemImage: "photo.badge.minus") }
        }
    }

    private func height(of image: UIImage) -> CGFloat {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return maxHeight }
        // 화면 폭 기준으로 눕혔을 때의 높이. 뚜껑보다 낮으면 통째로 보인다.
        let width = UIScreen.main.bounds.width - 32
        return min(width * size.height / size.width, maxHeight)
    }

    private func placeholder(_ text: String, systemImage: String, spinning: Bool = false) -> some View {
        HStack(spacing: 10) {
            if spinning { ProgressView().tint(Theme.accentInk) }
            Image(systemName: systemImage).foregroundStyle(Theme.accentInk)
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Paper.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 전체 화면으로 펼친 사진. 원본은 여기서 처음 읽는다.
struct PhotoViewer: View {
    let photo: AttachedPhoto
    let originalURL: URL?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var original: UIImage?
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = original ?? thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, $0.magnification) }.onEnded { _ in
                        withAnimation(Motion.settle(reduceMotion)) { scale = 1 }
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(String(localized: "사진 \(photo.name)"))
                    .accessibilityIdentifier("photo-viewer")
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).padding(12)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle).tint(.white)
            .padding(16)
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("photo-close")
        }
        .onTapGesture { dismiss() }
        .task {
            guard let originalURL else { return }
            original = await PhotoLoader.downsample(originalURL, maxPixel: 4096)
        }
    }

    private var thumbnail: UIImage? {
        if case .ready(let image) = photo.state { return image }
        return nil
    }
}
