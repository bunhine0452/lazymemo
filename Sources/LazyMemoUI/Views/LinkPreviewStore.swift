import AppKit
import LazyMemoCore
import LinkPresentation
import UniformTypeIdentifiers

/// 붙인 링크의 제목과 그림을 가져와 둔다.
///
/// **이것이 이 앱에서 네트워크를 쓰는 유일한 곳이다** (§9.3). 그래서 세 가지를
/// 지킨다: ① 설정으로 끌 수 있고, ② 한 번 가져온 것은 디스크에 남겨 다시 묻지
/// 않으며, ③ 실패한 주소는 그 세션 동안 다시 두드리지 않는다.
///
/// 정본은 여전히 마크다운이다. 여기서 가져온 것은 전부 파생물이라 통째로
/// 지워도 메모는 그대로다.
@MainActor
final class LinkPreviewStore {
    /// 링크 카드 한 장에 필요한 것만.
    struct Card: Identifiable, Equatable {
        let url: URL
        let title: String
        let image: NSImage?
        var id: String { url.absoluteString }

        var host: String {
            url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        }
    }

    /// 느린 주소 하나가 메모 전체를 붙잡지 않게 한다.
    private static let timeout: TimeInterval = 8
    /// 카드 그림의 최대 너비. 원본을 들고 있으면 메모리 예산(§11)이 무너진다.
    private static let thumbnailWidth: CGFloat = 480

    private let cacheDirectory: URL
    private let settings: SettingsStore
    private var memory: [URL: Card] = [:]
    /// 가져오지 못한 주소. 열 때마다 다시 두드리면 느리고 시끄럽다.
    private var failed: Set<URL> = []
    private var inFlight: Set<URL> = []

    init(cacheDirectory: URL, settings: SettingsStore) {
        self.cacheDirectory = cacheDirectory
        self.settings = settings
    }

    var isEnabled: Bool { settings.current.embedsLinks ?? true }

    /// 이미 알고 있으면 즉시 돌려준다. 모르면 `nil` 이고, 가져온 뒤에 다시 물어야 한다.
    func cached(_ url: URL) -> Card? {
        if let card = memory[url] { return card }
        guard let metadata = readFromDisk(url) else { return nil }
        let card = Card(url: url, title: title(from: metadata, url: url), image: nil)
        memory[url] = card
        return card
    }

    /// 없으면 가져온다. 이미 가져오는 중이면 아무것도 하지 않는다.
    func fetch(_ url: URL) async -> Card? {
        guard isEnabled, !failed.contains(url), !inFlight.contains(url) else { return memory[url] }
        if let card = memory[url], card.image != nil { return card }

        if let metadata = readFromDisk(url) {
            let card = await makeCard(from: metadata, url: url)
            memory[url] = card
            return card
        }

        inFlight.insert(url)
        defer { inFlight.remove(url) }

        let provider = LPMetadataProvider()
        provider.timeout = Self.timeout
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else {
            failed.insert(url)
            return nil
        }

        writeToDisk(metadata, for: url)
        let card = await makeCard(from: metadata, url: url)
        memory[url] = card
        return card
    }

    // MARK: 만들기

    private func makeCard(from metadata: LPLinkMetadata, url: URL) async -> Card {
        var image: NSImage?
        if let provider = metadata.imageProvider ?? metadata.iconProvider {
            image = await Self.loadImage(from: provider)
        }
        return Card(url: url, title: title(from: metadata, url: url), image: image)
    }

    private func title(from metadata: LPLinkMetadata, url: URL) -> String {
        if let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        // 제목을 못 얻어도 카드는 보인다 — 주소만 있는 카드가 날 것의 URL 보다 낫다.
        return url.host() ?? url.absoluteString
    }

    private static func loadImage(from provider: NSItemProvider) async -> NSImage? {
        guard provider.canLoadObject(ofClass: NSImage.self) else { return nil }
        let image: NSImage? = await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                continuation.resume(returning: object as? NSImage)
            }
        }
        guard let image else { return nil }
        return thumbnail(image)
    }

    private static func thumbnail(_ image: NSImage) -> NSImage {
        guard image.size.width > thumbnailWidth else { return image }
        let scale = thumbnailWidth / image.size.width
        let size = NSSize(width: thumbnailWidth, height: (image.size.height * scale).rounded())

        let reduced = NSImage(size: size)
        reduced.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        reduced.unlockFocus()
        return reduced
    }

    // MARK: 디스크 캐시

    private func location(for url: URL) -> URL {
        // 주소를 파일 이름으로 쓸 수 없으므로 안정적인 이름으로 바꾼다.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Data(url.absoluteString.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return cacheDirectory.appending(path: String(format: "%016llx.link", hash))
    }

    private func readFromDisk(_ url: URL) -> LPLinkMetadata? {
        guard let data = try? Data(contentsOf: location(for: url)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: LPLinkMetadata.self, from: data)
    }

    private func writeToDisk(_ metadata: LPLinkMetadata, for url: URL) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: metadata, requiringSecureCoding: true
        ) else { return }
        try? FileManager.default.createDirectory(
            at: cacheDirectory, withIntermediateDirectories: true
        )
        try? data.write(to: location(for: url), options: .atomic)
    }
}
