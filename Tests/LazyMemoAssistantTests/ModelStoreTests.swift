import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoAssistant

@Suite("ModelStore · ModelDownloader")
struct ModelStoreTests {
    func temp() -> URL {
        URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-models-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    /// 가짜 자산 — 파일 URL 을 내려받는다. 크기·해시는 그 파일의 것.
    func fakeManifest(bytes: Data, at dir: URL, sha256: String? = nil) throws -> (ModelManifest, URL) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let source = dir.appending(path: "source.litertlm", directoryHint: .notDirectory)
        try bytes.write(to: source)
        let hash = sha256 ?? Memo.contentHash(of: "")  // 자리만
        let m = ModelManifest(
            profileID: "test", displayName: "Test", upstreamModelID: "x/y", artifactRepo: "x/y", revision: "r",
            engine: "test", file: .init(name: "model.litertlm", bytes: Int64(bytes.count), sha256: hash),
            license: "none", contextTokens: 4096, templateVersion: 1)
        return (m, source)
    }

    func sha(_ data: Data) -> String {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "sha-\(UUID().uuidString)")
        try! data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try! ModelStore.sha256(of: url)
    }

    @Test("내려받아 검증하고 활성화하면 ready, 지우면 notDownloaded")
    func downloadActivateDelete() async throws {
        let root = temp(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data((0..<3_000_000).map { UInt8($0 % 251) })
        var (m, source) = try fakeManifest(bytes: payload, at: root.appending(path: "src"))
        m = ModelManifest(profileID: m.profileID, displayName: m.displayName, upstreamModelID: m.upstreamModelID,
                          artifactRepo: m.artifactRepo, revision: m.revision, engine: m.engine,
                          file: .init(name: m.file.name, bytes: m.file.bytes, sha256: sha(payload)),
                          license: m.license, contextTokens: m.contextTokens, templateVersion: m.templateVersion)
        let store = ModelStore(support: root.appending(path: "support"))
        #expect(await store.availability(m) == .notDownloaded)

        let downloader = ModelDownloader(store: store)
        var events: [DownloadEvent] = []
        for await e in downloader.download(TestURL.rewrite(m, to: source)) { events.append(e) }
        #expect(events.last == .ready)
        #expect(events.contains(.verifying))
        #expect(await store.availability(m) == .ready)
        #expect(!FileManager.default.fileExists(atPath: store.stagingURL(for: m).path(percentEncoded: false)))

        try await store.delete(m)
        #expect(await store.availability(m) == .notDownloaded)
    }

    @Test("해시가 다르면 활성 파일을 만들지 않고 staging 을 지운다")
    func checksumMismatchRejects() async throws {
        let root = temp(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data("hello".utf8)
        let (m, source) = try fakeManifest(bytes: payload, at: root.appending(path: "src"), sha256: String(repeating: "0", count: 64))
        let store = ModelStore(support: root.appending(path: "support"))
        var events: [DownloadEvent] = []
        for await e in ModelDownloader(store: store).download(TestURL.rewrite(m, to: source)) { events.append(e) }
        guard case .failed(let message) = events.last else { Issue.record("\(events)"); return }
        #expect(message.contains("손상"))
        #expect(await store.availability(m) == .notDownloaded)
        #expect(await store.stagedBytes(m) == 0)
    }

    @Test("이미 활성인 판은 새 판 검증이 실패해도 남는다")
    func activeSurvivesFailedActivation() async throws {
        let root = temp(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data("good".utf8)
        let (base, _) = try fakeManifest(bytes: payload, at: root.appending(path: "src"), sha256: sha(payload))
        let store = ModelStore(support: root.appending(path: "support"))
        try await store.prepareDirectory(base)
        try payload.write(to: store.stagingURL(for: base))
        try await store.activate(base)
        #expect(await store.availability(base) == .ready)

        try Data("badd".utf8).write(to: store.stagingURL(for: base))
        await #expect(throws: ModelStore.Failure.self) { try await store.activate(base) }
        #expect(await store.availability(base) == .ready)
        #expect(try Data(contentsOf: store.activeURL(for: base)) == payload)
    }
}

/// 테스트용 — manifest 의 URL 을 파일 URL 로 바꾼 사본.
enum TestURL {
    static func rewrite(_ m: ModelManifest, to file: URL) -> ModelManifest {
        ModelManifest(profileID: m.profileID, displayName: m.displayName, upstreamModelID: m.upstreamModelID,
                      artifactRepo: m.artifactRepo, revision: m.revision, engine: m.engine, file: m.file,
                      license: m.license, contextTokens: m.contextTokens, templateVersion: m.templateVersion,
                      overrideURL: file)
    }
}
