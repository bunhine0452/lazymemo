import Foundation
import LazyMemoCore

/// Spotlight 에 내놓는 메모 한 장 — **무엇을 보이는지는 여기서만 정한다.**
///
/// 결과 줄에 보이는 것은 제목과 둘째 줄이고, 본문 전체는 찾는 데만 쓰인다(보이지 않는다).
/// 날짜는 시스템이 아는 속성으로 넘긴다 — 「내일」같은 상대 낱말을 색인에 굳히면
/// 어제 색인한 「내일」이 오늘 거짓말이 된다. 태그·폴더·장소는 낱말로 넘겨 그 말로도 찾힌다.
public struct SpotlightEntry: Sendable, Equatable {
    /// Spotlight 의 uniqueIdentifier — 메모 id 그대로. 눌렀을 때 이것이 돌아온다.
    public let id: String
    public let title: String
    /// 결과 줄의 둘째 줄. 없으면 빈 문자열 — 시스템이 그 자리를 비운다.
    public let description: String
    /// 찾기에만 쓰이는 본문 전체.
    public let text: String
    public let keywords: [String]
    /// 일정이 있으면 그 시각(`at`) 또는 그 날의 시작(`due`).
    public let due: Date?
    public let modified: Date
    /// 이것이 같으면 다시 올리지 않는다 — 본문과 보이는 속성 전부의 지문.
    public let fingerprint: String

    /// 이 앱이 올린 것을 한 번에 내릴 때 쓰는 이름 (domainIdentifier).
    public static let domain = "memo"

    /// 찾을 것이 없는 메모(글도 사진도 없는 것)와 휴지통의 메모는 `nil` — 올리지 않는다.
    public init?(_ memo: Memo, calendar: Calendar = .current) {
        guard memo.deleted == nil else { return nil }
        guard !memo.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        id = memo.id.stringValue
        title = memo.title
        description = memo.previewLine ?? memo.place ?? ""
        text = memo.body
        keywords = (memo.tags + [memo.folder, memo.place].compactMap { $0 })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        due = memo.at ?? memo.due?.startOfDay(calendar: calendar)
        modified = memo.updated
        fingerprint = Memo.contentHash(of: [
            memo.body,
            memo.due?.description ?? "",
            memo.at.map { String($0.timeIntervalSince1970) } ?? "",
            memo.place ?? "",
            memo.folder ?? "",
            memo.tags.joined(separator: ","),
        ].joined(separator: "\u{1F}"))
    }

    /// 올릴 것만 — 순서는 넘어온 그대로.
    public static func entries(_ memos: [Memo], calendar: Calendar = .current) -> [SpotlightEntry] {
        memos.compactMap { SpotlightEntry($0, calendar: calendar) }
    }
}
