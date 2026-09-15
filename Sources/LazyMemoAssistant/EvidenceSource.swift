import Foundation
import LazyMemoCore

/// 검색·읽기 — Coordinator 가 근거를 모으는 창구. 쓰기는 없다.
public protocol EvidenceSource: Sendable {
    func search(_ query: String, limit: Int) async throws -> [Memo]
    func get(_ id: ULID) async throws -> Memo
    /// 오늘 브리핑 후보 — 기존 Recall 규칙(완료·휴지통 제외)을 따른다.
    func today(now: Date) async throws -> [Memo]
}

/// MemoService 위의 기본 구현. 질문은 낱말로 쪼개 `MemoRanker` 로 줄 세운다 — FTS 에 문장을
/// 통째로 던지면 「치과 언제였지?」가 「치과 예약 — …」을 못 찾는다 (명세 §4).
public struct MemoServiceEvidenceSource: EvidenceSource {
    let service: MemoService
    public init(service: MemoService) { self.service = service }

    public func search(_ query: String, limit: Int) async throws -> [Memo] {
        let all = try await service.all().filter(Recall.eligible)
        let ranked = MemoRanker.search(query, in: all, limit: limit)
        if !ranked.isEmpty { return ranked }
        // 낱말이 하나도 안 걸리면 옛길(FTS 구 검색)이라도 — 영어 한 단어 같은 경우.
        return try await service.search(query, limit: limit).filter(Recall.eligible)
    }

    public func get(_ id: ULID) async throws -> Memo { try await service.get(id) }

    public func today(now: Date) async throws -> [Memo] {
        let day = CalendarDate(now)
        let scheduled = try await service.scheduled(from: day, to: day)
        return scheduled.filter(Recall.eligible)
    }
}
