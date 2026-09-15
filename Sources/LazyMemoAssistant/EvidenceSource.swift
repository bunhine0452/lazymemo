import Foundation
import LazyMemoCore

/// 검색·읽기 — Coordinator 가 근거를 모으는 창구. 쓰기는 없다.
public protocol EvidenceSource: Sendable {
    func search(_ query: String, limit: Int) async throws -> [Memo]
    func get(_ id: ULID) async throws -> Memo
    /// 오늘 브리핑 후보 — 기존 Recall 규칙(완료·휴지통 제외)을 따른다.
    func today(now: Date) async throws -> [Memo]
}

/// MemoService 위의 기본 구현. 질의 확장·문단 자르기·토큰 예산은 `#evidence-retrieval` 에서 더한다.
public struct MemoServiceEvidenceSource: EvidenceSource {
    let service: MemoService
    public init(service: MemoService) { self.service = service }

    public func search(_ query: String, limit: Int) async throws -> [Memo] {
        try await service.search(query, limit: limit).filter(Recall.eligible)
    }

    public func get(_ id: ULID) async throws -> Memo { try await service.get(id) }

    public func today(now: Date) async throws -> [Memo] {
        let day = CalendarDate(now)
        let scheduled = try await service.scheduled(from: day, to: day)
        return scheduled.filter(Recall.eligible)
    }
}
