import Foundation
import Testing
@testable import LazyMemoCore

/// 빠른 입력의 초안이 앱을 껐다 켜도 남는지 (`CaptureDraftStore`).
@MainActor
@Suite("빠른 입력 초안 — 껐다 켜도 남는다")
struct CaptureDraftStoreTests {
    private func location() -> URL {
        URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-draft-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "capture-draft.txt", directoryHint: .notDirectory)
    }

    @Test("닫을 때 적은 것은 다음 실행이 도로 든다")
    func restoresAfterFlush() {
        let file = location()
        let first = CaptureDraftStore(location: file)
        first.remember("내일 오후 3시 치과\n보험증 챙기기")
        first.flush()

        let second = CaptureDraftStore(location: file)
        #expect(second.restored == "내일 오후 3시 치과\n보험증 챙기기")
    }

    @Test("확정하면 없어진다 — 파일도 남지 않는다")
    func forgetRemovesFile() {
        let file = location()
        let store = CaptureDraftStore(location: file)
        store.remember("장보기")
        store.flush()
        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))

        store.forget()
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(CaptureDraftStore(location: file).restored == "")
    }

    @Test("타자마다 쓰지 않고 잠깐 뒤에 쓴다 — 기다리면 스스로 적힌다")
    func writesAfterDebounce() async {
        let file = location()
        let store = CaptureDraftStore(location: file)
        store.remember("ㅈ")
        store.remember("장")
        store.remember("장보")
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))

        for _ in 0..<80 {
            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(CaptureDraftStore(location: file).restored == "장보")
    }

    @Test("파일이 없으면 빈 글로 시작한다")
    func startsEmpty() {
        #expect(CaptureDraftStore(location: location()).restored == "")
    }

    @Test("못 적으면 말한다 — 글은 들고 있고, 자리가 고쳐지면 다시 시도가 적는다")
    func reportsWriteFailureAndRetries() throws {
        // 부모 자리에 **파일**을 놓아 폴더를 만들 수 없게 한다 — 권한 거절·꽉 찬 디스크와 같은 꼴.
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-draft-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "support", directoryHint: .notDirectory)
        try Data("막힘".utf8).write(to: blocker)
        let file = blocker.appending(path: "capture-draft.txt", directoryHint: .notDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = CaptureDraftStore(location: file)
        store.remember("내일 견적 보내기")
        store.flush()

        #expect(store.trouble != nil, "조용히 삼키면 껐다 켠 뒤에야 안다")
        #expect(store.restored == "내일 견적 보내기", "이번 실행 동안은 들고 있다")

        // 자리가 고쳐졌다 — 다시 시도가 적고, 실패는 걷힌다.
        try FileManager.default.removeItem(at: blocker)
        store.retry()
        #expect(store.trouble == nil)
        #expect(CaptureDraftStore(location: file).restored == "내일 견적 보내기")
    }
}
