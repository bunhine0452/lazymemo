import Foundation

/// Vault 디렉터리의 파일 변경을 감시한다.
///
/// 필요한 이유는 **쓰는 주체가 앱만이 아니기 때문**이다. MCP 서버는 별도
/// 프로세스로 뜨고(설계문서 §9), 사용자가 마크다운을 텍스트 에디터로 직접
/// 고치는 것도 D4 가 광고하는 기능이다. 앱이 그 변화를 모르면 화면이 거짓말을 한다.
///
/// 하위 디렉터리(`notes/2026/08/`)까지 봐야 하므로 vnode 감시로는 부족하고
/// FSEvents 를 쓴다.
#if os(macOS)
public final class VaultWatcher: @unchecked Sendable {
    private let directories: [URL]
    private let latency: CFTimeInterval
    private let handler: @Sendable ([String]) -> Void
    private let queue = DispatchQueue(label: "io.github.bunhine0452.lazymemo.watcher")

    private var stream: FSEventStreamRef?

    public init(
        directories: [URL],
        latency: CFTimeInterval = 0.4,
        handler: @escaping @Sendable ([String]) -> Void
    ) {
        self.directories = directories
        self.latency = latency
        self.handler = handler
    }

    deinit { stop() }

    public func start() {
        guard stream == nil, !directories.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<VaultWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            watcher.handler(Array(changed.prefix(count)))
        }

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
        )

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            directories.map { $0.path(percentEncoded: false) } as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
        stream = created
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
#else
/// iOS 에는 FSEvents 가 없다. 대신 Vault 는 iCloud 컨테이너 안이라, iCloud 가
/// 무엇을 내려받고 무엇이 바뀌었는지 말해 주는 `NSMetadataQuery` 를 듣는다.
///
/// 하는 일이 둘이다.
///
/// 1. **바뀐 것을 알린다** — 맥에서 적은 메모가 내려오면 `handler` 가 불리고,
///    `MemoStore` 는 전체를 대조한다(맥의 FSEvents 와 같은 배선).
/// 2. **안 내려온 것을 내려받는다.** iCloud 는 목록만 먼저 주고 내용은 열 때
///    가져온다 — 그 자리에는 숨은 `.md.icloud` 가 있고 `MemoVault.scan` 은
///    숨은 파일을 건너뛴다. 그러니 우리가 청하지 않으면 그 메모는 화면에
///    **없다.** 여기서 보이는 족족 내려받기를 청하고, 내려오면 1 이 다시 돈다.
///
/// Vault 가 컨테이너 밖(로컬 폴백)이면 질의는 아무것도 못 찾고, 그때의 폰은
/// 쓰는 주체가 앱 하나뿐이라 들을 것도 없다.
public final class VaultWatcher: @unchecked Sendable {
    private let directories: [String]
    private let latency: TimeInterval
    private let handler: @Sendable ([String]) -> Void

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    public init(
        directories: [URL],
        latency: TimeInterval = 0.4,
        handler: @escaping @Sendable ([String]) -> Void
    ) {
        self.directories = directories.map { $0.standardizedFileURL.path(percentEncoded: false) }
        self.latency = latency
        self.handler = handler
    }

    deinit { stop() }

    public func start() {
        guard query == nil, !directories.isEmpty else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.\(MemoFile.fileExtension)")
        query.notificationBatchingInterval = latency

        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: query, queue: nil
            ) { [weak self] _ in self?.gathered(query) },
            center.addObserver(
                forName: .NSMetadataQueryDidUpdate, object: query, queue: nil
            ) { [weak self] note in self?.updated(query, note) },
        ]
        self.query = query

        // 질의는 런루프가 있는 스레드에서 시작해야 알림이 온다.
        DispatchQueue.main.async { query.start() }
    }

    public func stop() {
        guard let query else { return }
        query.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        self.query = nil
    }

    // MARK: 알림

    /// 첫 목록. 아직 안 내려온 것을 전부 청한다 — 폰을 처음 켰을 때 맥의 메모가
    /// 「있긴 한데 안 보이는」 상태로 남지 않게.
    private func gathered(_ query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let items = (0..<query.resultCount).compactMap { query.result(at: $0) as? NSMetadataItem }
        let paths = items.compactMap(location)
        requestDownloads(items)
        if !paths.isEmpty { handler(paths) }
    }

    private func updated(_ query: NSMetadataQuery, _ note: Notification) {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let keys = [
            NSMetadataQueryUpdateAddedItemsKey,
            NSMetadataQueryUpdateChangedItemsKey,
            NSMetadataQueryUpdateRemovedItemsKey,
        ]
        let items = keys.flatMap { note.userInfo?[$0] as? [NSMetadataItem] ?? [] }
        let paths = items.compactMap(location)
        requestDownloads(items)
        if !paths.isEmpty { handler(paths) }
    }

    /// 감시 중인 폴더 안의 것만. 컨테이너에는 `attachments/` 도 있다.
    private func location(of item: NSMetadataItem) -> String? {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return directories.contains { path.hasPrefix($0) } ? path : nil
    }

    private func requestDownloads(_ items: [NSMetadataItem]) {
        for item in items {
            guard let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
                  status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
                  let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  location(of: item) != nil
            else { continue }
            // 실패해도 다음 알림에 다시 청한다. 여기서 멈추면 그 한 장이 영영 안 보인다.
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }
}
#endif
