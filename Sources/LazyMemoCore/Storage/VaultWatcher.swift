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
/// iOS 에는 FSEvents 가 없다. 컨테이너 변경은 `NSMetadataQuery` 로 받는다 —
/// 그 구현은 동기화 단계에서 이 자리에 들어온다. 그 전까지는 아무것도 듣지
/// 않는 빈 감시자라, 앱이 켜질 때의 전체 대조(`MemoStore.reconcile`)만이 밖의
/// 변경을 보는 길이다.
// oculpm-defer: 빈 감시자 — 폰이 켜져 있는 동안 맥에서 온 변경을 못 본다; sync-watcher-ios 항목에서 NSMetadataQuery 로 채운다
public final class VaultWatcher: @unchecked Sendable {
    public init(
        directories: [URL],
        latency: CFTimeInterval = 0.4,
        handler: @escaping @Sendable ([String]) -> Void
    ) {}

    public func start() {}
    public func stop() {}
}
#endif
