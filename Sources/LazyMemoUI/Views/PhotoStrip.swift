import AppKit
import LazyMemoCore
import SwiftUI

/// 본문이 물고 있는 사진 한 장.
///
/// 메모 창과 빠른 입력이 같은 것을 쓴다 — 붙여넣기 경로가 하나이므로
/// (`AttachmentStore`) 화면에 담는 모양도 하나여야 한다.
struct AttachedImage: Identifiable, Equatable {
    let path: String
    let image: NSImage
    var id: String { path }
}

enum AttachedImages {
    /// 화면에 필요한 만큼으로 줄인다. 원본을 들고 있으면 메모 열 장에
    /// 메모리 예산(§11)이 무너진다. 원본은 펼쳐 볼 때만 다시 읽는다.
    static let thumbnailWidth: CGFloat = 480

    static func load(_ paths: [String], from store: AttachmentStore) -> [AttachedImage] {
        paths.compactMap { path in
            guard let url = store.url(for: path), let image = NSImage(contentsOf: url)
            else { return nil }
            return AttachedImage(path: path, image: thumbnail(image))
        }
    }

    static func thumbnail(_ image: NSImage, maxWidth: CGFloat = thumbnailWidth) -> NSImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let size = NSSize(width: maxWidth, height: (image.size.height * scale).rounded())

        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        thumbnail.unlockFocus()
        return thumbnail
    }
}

/// 종이에 붙인 사진 한 장.
///
/// **처음 판은 전폭으로 펼쳐 놓았는데, 기본 창 크기(260×200)에서 그것이
/// 메모를 통째로 잡아먹었다.** 글은 두 줄만 남고 사진은 종이 밖으로 삐져
/// 나갔다. 붙여넣기는 되고 있었는데 화면에서는 "안 되는" 것으로 보였다.
///
/// 그래서 사진이 차지할 수 있는 높이에 뚜껑을 씌운다. 잘려 보이는 대신
/// **포인터를 올리면 원본 크기로 펼친다** — 종이는 붙여 둔 자리이고, 제대로
/// 보는 것은 그때 하는 일이다.
struct PhotoStrip: View {
    let attachment: AttachedImage
    /// 원본 파일. 화면에 담고 있는 것은 줄인 그림이라(§11) 펼칠 때 다시 읽는다.
    let originalURL: URL?
    /// 종이 위에서 이 사진이 차지할 수 있는 최대 높이.
    var maxHeight: CGFloat = 116

    @State private var isHovering = false
    @State private var original: NSImage?

    /// 폭에 맞춰 눕혔을 때의 높이. 뚜껑보다 낮으면 통째로 보인다.
    private var aspect: CGFloat {
        let size = attachment.image.size
        guard size.width > 0, size.height > 0 else { return 1 }
        return size.height / size.width
    }

    var body: some View {
        GeometryReader { proxy in
            let height = min(proxy.size.width * aspect, maxHeight)
            Image(nsImage: attachment.image)
                .resizable()
                // 뚜껑에 걸리면 채워서 자른다. 눕혀 맞추면 폭이 남아 종이에
                // 붙인 사진이 아니라 화면 가운데 뜬 그림처럼 보인다.
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(.black.opacity(0.18), lineWidth: 0.75)
                )
                // 종이에 붙인 사진은 살짝 떠 있다.
                .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                // `.onHover` 는 키 윈도에서만 산다 (§7.1). 바탕화면의 종이에는
                // 쓸 수 없으므로 감지기를 따로 얹는다.
                .overlay { HoverSensor { hovering in
                    isHovering = hovering
                    if hovering { loadOriginal() }
                } }
                .popover(isPresented: $isHovering, arrowEdge: .trailing) {
                    FullSizePhoto(image: original ?? attachment.image)
                }
        }
        .frame(height: min(stripHeight, maxHeight))
    }

    /// `GeometryReader` 는 제 높이를 스스로 정하지 못한다. 바깥에서 못박아
    /// 주지 않으면 VStack 안에서 남은 자리를 통째로 먹는다 — 처음 판이 종이를
    /// 잡아먹은 것이 정확히 이것이었다.
    private var stripHeight: CGFloat {
        max(48, min(attachment.image.size.height, maxHeight))
    }

    private func loadOriginal() {
        guard original == nil, let originalURL else { return }
        original = NSImage(contentsOf: originalURL)
    }
}

/// 펼쳐 본 사진.
///
/// 원본 크기로 보이되 화면을 넘지 않는다 — 4000px 사진을 그대로 띄우면
/// 팝오버가 화면 밖으로 나가 아무것도 안 보인다.
struct FullSizePhoto: View {
    let image: NSImage

    private var size: CGSize {
        let natural = image.size
        guard natural.width > 0, natural.height > 0 else { return CGSize(width: 240, height: 180) }

        let room = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let limit = CGSize(width: room.width * 0.7, height: room.height * 0.7)
        let scale = min(1, min(limit.width / natural.width, limit.height / natural.height))
        return CGSize(width: (natural.width * scale).rounded(), height: (natural.height * scale).rounded())
    }

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
            .padding(Theme.tight)
    }
}


// MARK: - 작은 조각

/// 빠른 입력 말풍선에 붙은 사진.
///
/// 말풍선은 한 줄 적고 마는 자리라 사진을 펼칠 자리가 없다. 그런데 아무것도
/// 안 보이면 **붙여넣기가 안 된 것처럼 보인다** — 본문의 `![](…)` 는 꾸밈이
/// 감추고 있어서 화면에는 정말로 아무 일도 일어나지 않는다. 그래서 작은
/// 조각으로 "붙었다" 만 말하고, 제대로 보는 것은 포인터를 올렸을 때다.
struct PhotoChip: View {
    let attachment: AttachedImage
    let originalURL: URL?
    var side: CGFloat = 42

    @State private var isHovering = false
    @State private var original: NSImage?

    var body: some View {
        Image(nsImage: attachment.image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Paper.ink.opacity(0.18), lineWidth: 0.75)
            )
            .overlay { HoverSensor { hovering in
                isHovering = hovering
                if hovering, original == nil, let originalURL {
                    original = NSImage(contentsOf: originalURL)
                }
            } }
            .popover(isPresented: $isHovering, arrowEdge: .top) {
                FullSizePhoto(image: original ?? attachment.image)
            }
    }
}

/// 붙은 사진들을 가로로 늘어놓는다.
struct PhotoChipRow: View {
    let images: [AttachedImage]
    var originalURL: (AttachedImage) -> URL?

    /// 말풍선에 늘어놓을 수 있는 수. 넘치면 세어서 알린다.
    private static let shown = 5

    var body: some View {
        HStack(spacing: Theme.tight) {
            ForEach(images.prefix(Self.shown)) { attachment in
                PhotoChip(attachment: attachment, originalURL: originalURL(attachment))
            }
            if images.count > Self.shown {
                Text("+\(images.count - Self.shown)")
                    .font(Theme.label)
                    .foregroundStyle(Paper.fadedInk)
            }
        }
    }
}
