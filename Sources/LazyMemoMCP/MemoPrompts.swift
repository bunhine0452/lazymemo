import Foundation
import LazyMemoCore

/// Claude 에게 **무엇을 시킬 수 있는지** 사람에게 보여 준다 (MCP `prompts`).
///
/// 도구 목록(`MemoTools`)은 모델이 읽고, 이 목록은 **사람이 읽는다.** 지금까지
/// 비어 있던 쪽이 사람 쪽이었다 — MCP 를 등록해도 무엇을 시킬 수 있는지 모르면
/// 아무 일도 일어나지 않고, 그러면 「정리를 대신 해준다」(§1)의 절반은 등록만
/// 해 두고 영영 안 쓰이는 기능이 된다. Claude Desktop 은 이 목록을 슬래시 명령으로
/// 띄우므로, 사용자는 프롬프트를 지어내는 대신 고르기만 하면 된다.
///
/// **문구가 곧 제품이다.** 여기서 지키는 규칙 셋:
///
/// 1. **지우기 전에 묻는다.** 자동 정리가 조용히 지우면 그건 정리가 아니라 사고다.
///    D6 가 하드 삭제 도구를 아예 안 만든 것과 같은 이유로, 문장에서도 한 번 더 막는다.
/// 2. **적게 돌려준다.** 스무 개를 늘어놓는 답은 게으른 사람에게 «치워야 할 것»
///    하나를 더 만든다. 셋이면 셋이라고 문장에 적는다.
/// 3. **날짜와 장소를 채우게 한다.** 그 둘이 이 앱의 구조 전부다 (§14.2).
enum MemoPrompts {
    /// 이름은 ASCII 로 둔다 — 클라이언트가 슬래시 명령으로 바꿀 때 안전하다.
    /// 사람에게 보이는 말은 `title` 과 `description` 이 맡는다.
    /// `MemoTools.definitions` 와 같은 이유로 계산 프로퍼티다 — `[String: Any]` 는
    /// Sendable 이 아니라 전역 상수로 둘 수 없다.
    static var definitions: [[String: Any]] { [
        [
            "name": "weekly-tidy",
            "title": "이번 주 정리",
            "description": "쌓인 메모를 훑어 끝난 것은 치우고, 남을 것은 날짜를 붙인다",
        ],
        [
            "name": "today-three",
            "title": "오늘 뭐부터",
            "description": "지금 손댈 것 세 개만 고른다",
        ],
        [
            "name": "merge-scattered",
            "title": "흩어진 것 합치기",
            "description": "같은 얘기로 흩어진 메모를 하나로 모은다",
        ],
        [
            "name": "date-the-undated",
            "title": "날짜 없는 것 챙기기",
            "description": "날짜가 있어야 할 것 같은 메모에 날짜를 제안한다",
        ],
        [
            "name": "last-month",
            "title": "지난달 뭐 했더라",
            "description": "지난 30일의 메모를 짧게 되짚는다",
        ],
    ] }

    static func messages(for name: String) -> [[String: Any]]? {
        guard let text = script[name] else { return nil }
        return [["role": "user", "content": ["type": "text", "text": text]]]
    }

    static func definition(_ name: String) -> [String: Any]? {
        definitions.first { $0["name"] as? String == name }
    }

    private static let script: [String: String] = [
        "weekly-tidy": """
            lazymemo 의 메모를 훑어 이번 주를 정리해줘.

            1. list_memos 로 전체를 본다.
            2. **끝난 것**(다 체크한 목록, 지나간 일정, 이미 한 일)을 골라 목록으로 보여주고,
               내가 좋다고 하면 그때 delete_memo 로 옮긴다. **묻기 전에 지우지 마.**
            3. 남을 것 중 날짜가 있어야 할 것에는 due 나 at 을 제안한다.
            4. 어디서 하는 일인지 본문에 적혀 있으면 place 로 옮겨 준다.

            마지막에 한 줄로 알려줘 — 몇 장을 치웠고 몇 장에 날짜를 붙였는지.
            """,
        "today-three": """
            오늘 손대야 할 것 **세 개만** 골라줘.

            list_memos 로 오늘 날짜의 일정과 날짜 없는 메모를 함께 보고,
            지금 하는 편이 나은 순서로 셋을 고른다. 넷 이상 말하지 마 —
            고르라고 부른 것이지 늘어놓으라고 부른 것이 아니다.

            각각 왜 오늘인지 한 줄씩. 장소가 적혀 있으면 함께 말해줘.
            """,
        "merge-scattered": """
            같은 얘기로 흩어진 메모를 찾아 합쳐줘.

            1. list_memos 로 전체를 보고 주제가 겹치는 묶음을 찾는다.
            2. **어느 것을 어떻게 합칠지 먼저 보여준다.** 내가 좋다고 한 뒤에 손댄다.
            3. 합칠 때는 update_memo 로 한 장에 모으고, 나머지는 delete_memo 로 옮긴다.

            애매하면 합치지 마. 잘못 합친 것을 되돌리는 것이 흩어진 채로 두는 것보다 비싸다.
            """,
        "date-the-undated": """
            날짜가 없는데 있어야 할 것 같은 메모를 찾아줘.

            list_memos 로 due 와 at 이 모두 빈 메모를 보고, 그중 «언제까지» 가
            있어야 말이 되는 것을 고른다(예약·마감·연락·결제).

            각각 언제로 하면 좋을지 제안하고, **내가 좋다고 한 것만** update_memo 로 붙인다.
            """,
        "last-month": """
            지난 30일 동안 무슨 일이 있었는지 짧게 되짚어줘.

            list_memos 의 from·to 로 그 기간을 보고, 열 줄 안쪽으로 정리한다.
            빠짐없이 적는 것이 목적이 아니다 — 다시 볼 만한 것만 남긴다.
            """,
    ]
}
