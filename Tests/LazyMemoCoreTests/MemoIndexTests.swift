import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoIndex")
struct MemoIndexTests {
    private func makeIndex() throws -> (MemoIndex, URL) {
        let location = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-index-\(UUID().uuidString).sqlite", directoryHint: .notDirectory)
        return (try MemoIndex(path: location), location)
    }

    private func put(_ index: MemoIndex, _ memo: Memo) async throws {
        try await index.upsert(memo, relativePath: "notes/x/\(memo.id).md", modifiedAt: memo.updated)
    }

    @Test("넣은 메모를 되찾는다")
    func storesAndLists() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let memo = Memo(body: "치과 예약")
        try await put(index, memo)

        let all = try await index.all()
        #expect(all.map(\.id) == [memo.id])
        #expect(all.first?.relativePath.hasPrefix("notes/") == true)
    }

    @Test("같은 id 를 다시 넣으면 갱신된다")
    func upsertReplaces() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        var memo = Memo(body: "처음")
        try await put(index, memo)
        memo.color = .pink
        try await put(index, memo)

        let all = try await index.all()
        #expect(all.count == 1)
        #expect(all.first?.color == .pink)
    }

    @Test("한글 세 글자 이상은 trigram 으로 찾는다")
    func searchesKoreanWithTrigram() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let target = Memo(body: "치과 예약 — 강남역 3번 출구")
        try await put(index, target)
        try await put(index, Memo(body: "장보기 목록"))

        #expect(try await index.search("강남역").map(\.id) == [target.id])
        #expect(try await index.search("과 예약").map(\.id) == [target.id])
    }

    @Test("두 글자 한국어도 찾는다 — trigram 이 못 하는 구간의 LIKE 폴백")
    func searchesShortKoreanWithLikeFallback() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let target = Memo(body: "병원 다녀오기")
        try await put(index, target)
        try await put(index, Memo(body: "장보기 목록"))

        #expect(try await index.search("병원").map(\.id) == [target.id])
    }

    @Test("LIKE 와일드카드를 글자 그대로 취급한다")
    func escapesLikeWildcards() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        try await put(index, Memo(body: "아무 내용"))
        #expect(try await index.search("%").isEmpty)
        #expect(try await index.search("_").isEmpty)
    }

    @Test("날짜 범위 조회가 due 와 at 을 모두 본다")
    func rangeQueryCoversBothDateFields() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let dueMemo = Memo(due: CalendarDate(year: 2026, month: 9, day: 3), body: "마감")
        let atMemo = Memo(
            at: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 14))!,
            body: "약속"
        )
        let outside = Memo(due: CalendarDate(year: 2026, month: 10, day: 1), body: "다음 달")
        let plain = Memo(body: "날짜 없는 메모")

        for memo in [dueMemo, atMemo, outside, plain] { try await put(index, memo) }

        let found = try await index.scheduled(
            from: CalendarDate(year: 2026, month: 9, day: 1),
            to: CalendarDate(year: 2026, month: 9, day: 30)
        )

        #expect(Set(found.map(\.id)) == Set([dueMemo.id, atMemo.id]))
    }

    @Test("범위 마지막 날의 늦은 시각도 포함한다")
    func rangeIncludesLastDayEvening() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59))!
        let memo = Memo(at: lateEvening, body: "월말 회식")
        try await put(index, memo)

        let found = try await index.scheduled(
            from: CalendarDate(year: 2026, month: 9, day: 1),
            to: CalendarDate(year: 2026, month: 9, day: 30)
        )
        #expect(found.map(\.id) == [memo.id])
    }

    @Test("고정된 메모가 먼저 나온다")
    func pinnedComesFirst() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let old = Memo(updated: Date(timeIntervalSince1970: 1_000_000), pinned: true, body: "고정된 옛 메모")
        let fresh = Memo(updated: Date(), body: "최근 메모")
        try await put(index, fresh)
        try await put(index, old)

        #expect(try await index.all().map(\.id) == [old.id, fresh.id])
    }

    @Test("지우면 검색에서도 사라진다")
    func removeDropsFromFullText() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let memo = Memo(body: "삭제 대상 메모")
        try await put(index, memo)
        try await index.remove(memo.id)

        #expect(try await index.all().isEmpty)
        #expect(try await index.search("삭제 대상").isEmpty)
    }

    @Test("mtime 지문으로 변경분만 골라낼 수 있다")
    func exposesFingerprints() async throws {
        let (index, location) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: location) }

        let memo = Memo(body: "본문")
        let stamp = Date(timeIntervalSince1970: 1_787_000_000)
        try await index.upsert(memo, relativePath: "notes/a.md", modifiedAt: stamp)

        #expect(try await index.fingerprints() == [memo.id: stamp])
    }
}
