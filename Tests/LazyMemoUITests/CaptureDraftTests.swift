import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 빠른 입력이 들고 있던 글이 앱을 껐다 켜도 남는지, 그리고 첫소리로도
/// 찾는지 — 상자 모델(`QuickCaptureModel`)에 대고 묻는다.
@MainActor
@Suite("빠른 입력 — 껐다 켜도 기억하고, 첫소리로도 찾는다")
struct CaptureDraftTests {
    private func makePaths() throws -> AppPaths {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-capture-draft-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return paths
    }

    /// 목록이 다시 지어질 때까지 — 검색은 디바운스를 거친다. 시간이 아니라 조건을 기다린다.
    private func settle(until: () -> Bool) async {
        for _ in 0..<80 {
            if until() { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test("닫을 때 들고 있던 글을 다음 실행의 상자가 도로 든다")
    func draftSurvivesRestart() async throws {
        let paths = try makePaths()
        let store = try MemoStore(paths: paths)

        let before = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        before.query = "내일 오후 3시 치과\n보험증 챙기기"
        // 상자를 닫는 순간 하는 일 (`QuickCaptureController.close`).
        before.flushDraft()

        let after = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        #expect(after.query == "내일 오후 3시 치과\n보험증 챙기기")
        // 글만이 아니라 그 글이 뜻하던 것도 함께 돌아온다.
        #expect(after.schedule != nil)
    }

    @Test("확정하면 초안은 없어진다 — 다음 실행은 빈 상자로 시작한다")
    func commitForgetsDraft() async throws {
        let paths = try makePaths()
        let store = try MemoStore(paths: paths)

        let model = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        model.query = "우유 사기"
        model.flushDraft()
        // ⌘⏎ 뒤에 컨트롤러가 하는 일.
        model.clear()

        #expect(!FileManager.default.fileExists(atPath: paths.captureDraft.path(percentEncoded: false)))
        let next = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        #expect(next.query.isEmpty)
    }

    @Test("도로 든 글로 다시 찾는다 — 껐다 켠 직후 목록이 비어 있으면 안 된다")
    func reopeningSearchesAgain() async throws {
        let paths = try makePaths()
        let store = try MemoStore(paths: paths)
        _ = try await store.create(body: "치과 예약")

        let before = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        before.query = "치과"
        before.flushDraft()

        // 새 실행 — 상자가 만들어질 때는 메모를 아직 안 읽었다.
        let freshStore = try MemoStore(paths: paths)
        let after = QuickCaptureModel(store: freshStore, draft: CaptureDraftStore(location: paths.captureDraft))
        await freshStore.start()
        after.prepareForShow()
        await settle { after.listing == .found && !after.pool.isEmpty }

        #expect(after.pool.count == 1)
        #expect(after.pool.first?.body == "치과 예약")
    }

    @Test("적기가 실패하면 글은 상자에 그대로 있고 그 까닭이 적힌다 — 고쳐 적기 시작하면 걷힌다")
    func failedSaveKeepsTheText() async throws {
        let paths = try makePaths()
        let store = try MemoStore(paths: paths)
        let model = QuickCaptureModel(store: store, draft: CaptureDraftStore(location: paths.captureDraft))
        model.query = "내일 견적 보내기"

        // 정본 자리를 파일로 막아 다음 쓰기가 반드시 실패하게 한다.
        try FileManager.default.removeItem(at: paths.notes)
        try Data("막힘".utf8).write(to: paths.notes)
        let memo = await model.save { try await store.create(body: model.query) }

        #expect(memo == nil)
        #expect(model.saveTrouble != nil)
        #expect(model.query == "내일 견적 보내기", "실패했는데 글이 없으면 「적었는데 없다」다")

        model.query = "내일 견적 보내기!"
        #expect(model.saveTrouble == nil, "새 글이 새 시도다")

        // 자리가 고쳐졌다 — 같은 손짓이 이번엔 적는다.
        try FileManager.default.removeItem(at: paths.notes)
        try paths.createDirectories()
        let saved = await model.save { try await store.create(body: model.query) }
        #expect(saved != nil)
        #expect(model.saveTrouble == nil)
    }

    @Test("초안이 기기에 안 남으면 상자가 말하고, 「다시 시도」가 적는다")
    func draftTroubleSurfaces() throws {
        let paths = try makePaths()
        let store = try MemoStore(paths: paths)
        // 초안 자리의 부모를 파일로 막는다.
        let blocked = paths.support.appending(path: "blocked", directoryHint: .notDirectory)
        try Data("막힘".utf8).write(to: blocked)
        let draft = CaptureDraftStore(location: blocked.appending(path: "capture-draft.txt", directoryHint: .notDirectory))
        let model = QuickCaptureModel(store: store, draft: draft)

        model.query = "세 줄 적던 것"
        model.flushDraft()
        #expect(model.draftTrouble != nil)
        #expect(model.query == "세 줄 적던 것", "이번 실행 동안은 들고 있다")

        try FileManager.default.removeItem(at: blocked)
        model.retryDraft()
        #expect(model.draftTrouble == nil)
    }

    @Test("첫소리로도 찾는다 — 「ㅈㅂㄱ」가 「장보기」를")
    func findsByInitials() async throws {
        let store = try MemoStore(paths: try makePaths())
        _ = try await store.create(body: "장보기 목록\n- 우유")
        _ = try await store.create(body: "치과 예약")

        let model = QuickCaptureModel(store: store)
        model.query = "ㅈㅂㄱ"
        await settle { model.listing == .found }

        #expect(model.pool.count == 1)
        #expect(model.pool.first?.title == "장보기 목록")
    }

    @Test("첫소리와 생김새를 같이 쓴다 — 「#체크 ㅈㅂㄱ」")
    func initialsCombineWithFilters() async throws {
        let store = try MemoStore(paths: try makePaths())
        _ = try await store.create(body: "장보기\n- [ ] 우유")
        _ = try await store.create(body: "장보기 메모 — 지난주")

        let model = QuickCaptureModel(store: store)
        model.query = "#체크 ㅈㅂㄱ"
        await settle { model.listing == .found }

        #expect(model.pool.count == 1)
        #expect(model.pool.first?.body.contains("[ ]") == true)
    }

    @Test("섞인 글은 보통 글자로 본다 — 「ㅈ보기」는 아무것도 못 찾는다")
    func mixedQueryIsPlainText() async throws {
        let store = try MemoStore(paths: try makePaths())
        _ = try await store.create(body: "장보기")

        let model = QuickCaptureModel(store: store)
        model.query = "ㅈ보기"
        await settle { model.listing == .found }

        #expect(model.pool.isEmpty)
    }
}
