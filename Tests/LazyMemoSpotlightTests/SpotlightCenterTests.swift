import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoSpotlight

/// 시스템 색인의 가짜. 무엇을 올렸고 무엇을 내렸는지 기억한다.
@MainActor
final class FakeIndex: SpotlightIndex {
    var available = true
    var items: [String: SpotlightEntry] = [:]
    var indexedIDs: [String] = []
    var removedIDs: [String] = []
    var removedAll = 0
    var failing = false

    func index(_ entries: [SpotlightEntry]) async throws {
        if failing { throw CocoaError(.fileWriteUnknown) }
        for entry in entries {
            items[entry.id] = entry
            indexedIDs.append(entry.id)
        }
    }

    func remove(ids: [String]) async throws {
        for id in ids { items[id] = nil }
        removedIDs += ids
    }

    func removeAll() async throws {
        items = [:]
        removedAll += 1
    }
}

@MainActor
@Suite("SpotlightCenter — 저장소와 시스템 색인의 대조")
struct SpotlightCenterTests {
    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-spotlight-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    /// 임시 폴더와 `UserDefaults` 도메인이 같은 이름을 쓴다 — 지울 때 같이 지우려고 (`ReminderCenterTests` 와 같다).
    private func cleanUp(_ paths: AppPaths) {
        let root = paths.vault.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: root)
        let name = root.lastPathComponent
        let defaults = UserDefaults(suiteName: name)
        defaults?.removePersistentDomain(forName: name)
        defaults?.synchronize()
        let plist = URL.libraryDirectory.appending(path: "Preferences/\(name).plist")
        try? FileManager.default.removeItem(at: plist)
    }

    private func defaults(for paths: AppPaths) -> UserDefaults {
        let name = paths.vault.deletingLastPathComponent().lastPathComponent
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func make(enabled: Bool? = nil) throws -> (SpotlightCenter, FakeIndex, MemoStore, AppPaths) {
        let (store, paths) = try makeStore()
        let index = FakeIndex()
        let defaults = defaults(for: paths)
        if let enabled { defaults.set(enabled, forKey: "spotlight.enabled") }
        let center = SpotlightCenter(index: index, defaults: defaults)
        return (center, index, store, paths)
    }

    @Test("기본은 켜짐 — 붙이면 글이 있는 메모가 올라가고, 빈 메모는 올라가지 않는다")
    func indexesOnStart() async throws {
        let (center, index, store, paths) = try make()
        defer { cleanUp(paths) }
        let dentist = try await store.create(body: "치과 예약\n강남역 3번 출구", place: "강남역")
        _ = try await store.create(body: "   \n")

        center.start(store: store)
        await center.settle()

        #expect(center.enabled)
        #expect(index.items.count == 1)
        let entry = try #require(index.items[dentist.id.stringValue])
        #expect(entry.title == "치과 예약")
        #expect(entry.description == "강남역 3번 출구")
        #expect(entry.text == dentist.body)
        #expect(entry.keywords == ["강남역"])
        #expect(center.indexedCount == 1)
        #expect(center.trouble == nil)
    }

    @Test("바뀐 것만 다시 올리고, 지운 것은 내린다")
    func reconcilesChanges() async throws {
        let (center, index, store, paths) = try make()
        defer { cleanUp(paths) }
        let a = try await store.create(body: "우유 사기")
        let b = try await store.create(body: "책 반납")
        center.start(store: store)
        await center.settle()
        #expect(Set(index.indexedIDs) == [a.id.stringValue, b.id.stringValue])
        index.indexedIDs.removeAll()

        _ = try await store.update(a.id, body: "우유·계란 사기")
        await center.settle()
        #expect(index.indexedIDs == [a.id.stringValue])
        #expect(index.items[a.id.stringValue]?.title == "우유·계란 사기")
        index.indexedIDs.removeAll()

        // 아무것도 안 바뀐 대조는 아무것도 올리지 않는다.
        center.refresh()
        await center.settle()
        #expect(index.indexedIDs.isEmpty)

        try await store.delete(b.id)
        await center.settle()
        #expect(index.removedIDs == [b.id.stringValue])
        #expect(index.items.count == 1)
        #expect(center.indexedCount == 1)
    }

    @Test("끄면 올려 둔 것을 전부 내리고, 다시 켜면 전부 올린다")
    func disableRemovesEverything() async throws {
        let (center, index, store, paths) = try make()
        defer { cleanUp(paths) }
        _ = try await store.create(body: "회의 자료")
        center.start(store: store)
        await center.settle()
        #expect(index.items.count == 1)

        center.setEnabled(false)
        await center.settle()
        #expect(index.removedAll == 1)
        #expect(index.items.isEmpty)
        #expect(center.indexedCount == 0)

        // 꺼진 동안의 변경은 올리지 않는다.
        _ = try await store.create(body: "꺼진 동안 적은 것")
        await center.settle()
        #expect(index.items.isEmpty)

        center.setEnabled(true)
        await center.settle()
        #expect(index.items.count == 2)
    }

    @Test("꺼 둔 채 시작하면 색인을 건드리지 않는다")
    func startsDisabled() async throws {
        let (center, index, store, paths) = try make(enabled: false)
        defer { cleanUp(paths) }
        _ = try await store.create(body: "적어 둔 것")
        center.start(store: store)
        await center.settle()
        #expect(!center.enabled)
        #expect(index.items.isEmpty)
        #expect(index.removedAll == 0)
    }

    @Test("지문은 UserDefaults 에 남아 다음 실행이 바뀐 것만 올린다")
    func remembersFingerprints() async throws {
        let (store, paths) = try makeStore()
        let index = FakeIndex()
        defer { cleanUp(paths) }
        let a = try await store.create(body: "첫 장")
        let b = try await store.create(body: "둘째 장")

        // 첫 실행은 닫힌 범위 안에서 — 범위를 나가면 center 가 놓여 저장소 관찰이 멎는다. 튜플로 받아 두면
        // 튜플이 그것을 붙들고 있어 아래 변경에 둘이 함께 올려 `indexedIDs` 가 두 번 적혔다 (셋 중 하나꼴로 빨갰다).
        do {
            let first = SpotlightCenter(index: index, defaults: defaults(for: paths))
            first.start(store: store)
            await first.settle()
        }
        // 같은 defaults 로 새 center — 앱을 다시 켠 것과 같다.
        let again = SpotlightCenter(index: index, defaults: defaults(for: paths, keep: true))
        index.indexedIDs.removeAll()
        _ = try await store.update(b.id, body: "둘째 장 — 고침")
        again.start(store: store)
        await again.settle()
        #expect(index.indexedIDs == [b.id.stringValue])
        #expect(index.items[a.id.stringValue] != nil)
    }

    @Test("색인을 못 쓰는 기기에서는 올리지 않고 그렇게 적는다")
    func unavailableIsReported() async throws {
        let (center, index, store, paths) = try make()
        defer { cleanUp(paths) }
        index.available = false
        _ = try await store.create(body: "무엇")
        center.start(store: store)
        await center.settle()
        #expect(index.items.isEmpty)
        #expect(center.trouble != nil)
    }

    @Test("올리기가 실패하면 삼키지 않고 적고, 다음 대조에서 다시 올린다")
    func failureIsReportedAndRetried() async throws {
        let (center, index, store, paths) = try make()
        defer { cleanUp(paths) }
        index.failing = true
        _ = try await store.create(body: "무엇")
        center.start(store: store)
        await center.settle()
        #expect(center.trouble != nil)
        #expect(index.items.isEmpty)

        index.failing = false
        center.refresh()
        await center.settle()
        #expect(center.trouble == nil)
        #expect(index.items.count == 1)
    }

    @Test("SpotlightEntry — 날짜는 속성으로, 태그·폴더·장소는 낱말로, 휴지통은 빠진다")
    func entryShape() throws {
        var memo = Memo(tags: ["건강"], body: "# 병원\n오후 진료")
        memo.folder = "집"
        memo.place = "서울대병원"
        memo.due = CalendarDate(year: 2026, month: 9, day: 20)
        let entry = try #require(SpotlightEntry(memo))
        #expect(entry.title == "병원")
        #expect(entry.description == "오후 진료")
        #expect(entry.keywords == ["건강", "집", "서울대병원"])
        #expect(entry.due == memo.due?.startOfDay())
        let before = entry.fingerprint

        memo.tags = []
        #expect(SpotlightEntry(memo)?.fingerprint != before)

        memo.deleted = Date()
        #expect(SpotlightEntry(memo) == nil)
    }

    private func defaults(for paths: AppPaths, keep: Bool) -> UserDefaults {
        let name = paths.vault.deletingLastPathComponent().lastPathComponent
        let defaults = UserDefaults(suiteName: name)!
        if !keep { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}
