import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 낱말이 기억나지 않을 때 돌아가는 길 (`{#recall-chips}`·`{#recall-ranking}`).
@MainActor
@Suite("게으른 찾기")
struct CaptureRecallTests {
    private func makeStore() throws -> MemoStore {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-recall-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return try MemoStore(paths: paths)
    }

    /// 목록이 다시 지어질 때까지 기다린다 — 검색은 디바운스를 거친다.
    ///
    /// **고정 시간으로 기다리면 깜빡인다.** 기계가 바쁘면 320ms 안에 안 끝나고,
    /// 그때 시험은 «못 찾았다» 로 읽는다 — 코드가 아니라 시험이 진 것이다.
    /// 그래서 시간이 아니라 **조건**을 기다린다.
    private func settle(_ model: QuickCaptureModel, until: () -> Bool) async {
        for _ in 0..<80 {
            if until() { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test("낱말 없이 생김새만으로 찾는다 — 「그 사진 붙여 둔 거」")
    func findsByShapeAlone() async throws {
        let store = try makeStore()
        _ = try await store.create(body: "영수증\n![](x.png)")
        _ = try await store.create(body: "그냥 메모")

        let model = QuickCaptureModel(store: store)
        model.query = "#사진"
        await settle(model) { model.listing == .found }

        #expect(model.filter.shapes == [.photo])
        #expect(model.pool.count == 1)
        #expect(model.pool.first?.body.contains("영수증") == true)
    }

    @Test("장소로도 찾는다")
    func findsByPlace() async throws {
        let store = try makeStore()
        _ = try await store.create(body: "커피", place: "광화문 교보문고")
        _ = try await store.create(body: "치과", place: "강남역")

        let model = QuickCaptureModel(store: store)
        model.query = "@강남"
        await settle(model) { !model.pool.isEmpty }

        #expect(model.pool.count == 1)
        #expect(model.pool.first?.place == "강남역")
    }

    @Test("무엇으로 걸렀는지 화면에 적을 말을 들고 있다")
    func exposesChips() async throws {
        let model = QuickCaptureModel(store: try makeStore())
        model.query = "#사진 @강남"
        #expect(model.filter.chips == ["#사진", "@강남"])
    }

    @Test("조건이 없으면 예전과 똑같이 낱말로 찾는다")
    func plainSearchUnchanged() async throws {
        let store = try makeStore()
        _ = try await store.create(body: "영수증 정리")
        _ = try await store.create(body: "장보기")

        let model = QuickCaptureModel(store: store)
        model.query = "영수증"
        await settle(model) { !model.pool.isEmpty }

        #expect(!model.filter.narrows)
        #expect(model.pool.count == 1)
    }

    @Test("읽기만 한 메모도 「요즘」에 든다 — 고친 때만 세면 밀려난다")
    func recentIncludesWhatWasOpened() async throws {
        let store = try makeStore()
        _ = try await store.create(body: "먼저 적은 것")
        _ = try await store.create(body: "나중에 적은 것")

        // 같은 초에 적은 둘은 `updated` 가 같아 차례가 정해지지 않는다.
        // 그러니 **지금 위가 아닌 쪽**을 열어 보고, 그것이 올라오는지를 본다.
        let plain = QuickCaptureModel(store: store)
        plain.query = ""
        guard let buried = plain.pool.last else { Issue.record("목록이 비었다"); return }

        let opened = QuickCaptureModel(
            store: store,
            lastOpened: { $0 == buried.id ? Date().addingTimeInterval(60) : nil }
        )
        opened.query = ""
        #expect(opened.pool.first?.id == buried.id)
    }

    @Test("고정한 것은 무엇을 열어 보든 여전히 맨 위다")
    func pinnedStaysOnTop() async throws {
        let store = try makeStore()
        let pinned = try await store.create(body: "고정")
        _ = try await store.update(pinned.id, pinned: true)
        let other = try await store.create(body: "보통")

        let model = QuickCaptureModel(
            store: store,
            lastOpened: { $0 == other.id ? Date().addingTimeInterval(600) : nil }
        )
        model.query = ""
        #expect(model.pool.first?.id == pinned.id)
    }
}
