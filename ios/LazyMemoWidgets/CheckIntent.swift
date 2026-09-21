import AppIntents
import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore

/// 체크 — 홈 화면에서 바로 그 칸을 체크한다. **앱을 열지 않는다.**
///
/// 「봤어요」(`SeenIntent`)가 이 기기의 기억에 적는 것과 달리 이것은 **메모 파일에 적는다** —
/// 체크된 칸은 맥의 종이에서도 체크돼야 한다. 확장이 파일을 고치는 첫 자리라 규칙은 좁다
/// (`WidgetChecklist.check`): 괄호 안 한 글자와 `updated` 뿐, 줄은 글로 찾고, 그 사이 파일이
/// 바뀌었으면 손대지 않는다. 앱은 앞으로 나올 때 파일을 대조해 인덱스와 「다 체크한 목록은
/// 물러난다」를 챙긴다.
///
/// `perform()` 이 돌아오면 시스템이 이 위젯의 시간표를 다시 부른다 — 체크된 줄은 목록에서
/// 빠진다. 맥 위젯에도 있다: App Group 이 필요 없고, 읽은 자리(iCloud 컨테이너)에 그대로 쓴다.
struct CheckIntent: AppIntent {
    static let title: LocalizedStringResource = "체크"
    static var description: IntentDescription { IntentDescription("「지금」의 체크리스트 한 칸을 체크합니다.") }

    /// 어느 메모인가 (ULID).
    @Parameter(title: "메모") var memo: String
    /// 어느 칸인가 — 상자 뒤의 글. 자리가 아니라 글로 찾는다.
    @Parameter(title: "항목") var item: String

    init() {}

    init(item: WidgetChecklist.Item) {
        self.memo = item.memo.description
        self.item = item.text
    }

    func perform() async throws -> some IntentResult {
        guard let id = ULID(memo) else { return .result() }
        _ = try? await WidgetChecklist.check(item, of: id, in: WidgetVault.paths())
        return .result()
    }
}
