import Foundation

public enum DownloadEvent: Sendable, Equatable {
    case progress(received: Int64, total: Int64)
    case verifying
    case ready
    case failed(String)
}

/// 파일 하나를 이어받는다 — `Range` 헤더로 받다 만 곳부터. 취소는 Task 취소.
/// 다 받으면 `ModelStore.activate` 가 검증하고 교체한다. 자산 다운로드 말고는 네트워크를 쓰지 않는다.
public struct ModelDownloader: Sendable {
    let store: ModelStore
    let session: URLSession

    public init(store: ModelStore, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    public func download(_ m: ModelManifest) -> AsyncStream<DownloadEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    try await run(m) { continuation.yield($0) }
                    continuation.yield(.ready)
                } catch is CancellationError {
                    // 받다 만 파일은 남긴다 — 다음에 이어받는다.
                } catch {
                    continuation.yield(.failed(Self.describe(error)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ m: ModelManifest, emit: @Sendable (DownloadEvent) -> Void) async throws {
        try await store.prepareDirectory(m)
        try await store.ensureDiskSpace(m)
        let staging = store.stagingURL(for: m)
        var offset = await store.stagedBytes(m)
        if offset > m.file.bytes { try? FileManager.default.removeItem(at: staging); offset = 0 }

        if offset < m.file.bytes {
            var request = URLRequest(url: m.downloadURL)
            let canResume = offset > 0 && m.downloadURL.scheme?.hasPrefix("http") == true
            if canResume { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse {
                guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                // 서버가 Range 를 무시하고 처음부터 주면 처음부터 받는다.
                if canResume && http.statusCode != 206 { offset = 0 }
            }
            if offset == 0 { try? FileManager.default.removeItem(at: staging) }
            if !FileManager.default.fileExists(atPath: staging.path(percentEncoded: false)) {
                FileManager.default.createFile(atPath: staging.path(percentEncoded: false), contents: nil)
            }
            let handle = try FileHandle(forWritingTo: staging)
            defer { try? handle.close() }
            try handle.seekToEnd()
            var received = offset
            var buffer = Data()
            buffer.reserveCapacity(1 << 20)
            var lastReport = Date.distantPast
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= (1 << 20) {
                    try Task.checkCancellation()
                    try handle.write(contentsOf: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    if Date().timeIntervalSince(lastReport) > 0.25 {
                        lastReport = Date()
                        emit(.progress(received: received, total: m.file.bytes))
                    }
                }
            }
            if !buffer.isEmpty { try handle.write(contentsOf: buffer); received += Int64(buffer.count) }
            try handle.synchronize()
            emit(.progress(received: received, total: m.file.bytes))
        }
        emit(.verifying)
        try await store.activate(m)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case ModelStore.Failure.checksumMismatch: return "받은 파일이 손상되어 지웠습니다. 다시 받아 주세요"
        case ModelStore.Failure.sizeMismatch: return "받은 파일의 크기가 다릅니다"
        case ModelStore.Failure.insufficientDisk(let needed, _):
            return "저장 공간이 부족합니다 — \(ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)) 필요"
        case let url as URLError where url.code == .notConnectedToInternet: return "인터넷에 연결되어 있지 않습니다"
        default: return String(describing: error)
        }
    }
}
