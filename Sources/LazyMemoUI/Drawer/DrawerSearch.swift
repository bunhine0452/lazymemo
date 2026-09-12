import Foundation
import LazyMemoCore

/// 서랍에서 **찾는 일** — 뷰 밖의 순수 규칙.
///
/// ## 왜 서랍에만 찾기가 있는가
///
/// 이 앱은 폴더도 태그도 만들지 않는다 (철학 2). 그 대가는 **밀어 둔 종이가
/// 쌓이면 손으로 뒤져야 한다**는 것이다. 무더기는 여덟 장까지만 겹치고
/// (`DrawerGeometry.visible`) 나머지는 「그리고 N장 더」라는 한 줄로만 남는데,
/// 스무 장이 넘어가면 그 한 줄이 곧 «어딘가 있는데 못 찾는다» 가 된다.
///
/// 찾기는 분류를 만들지 않는다. **거르기일 뿐이고 아무것도 남기지 않는다** —
/// 글자를 지우면 무더기는 그대로 돌아온다. §16.1 이 지킨 「폴더인데 분류가
/// 아니다」를 어기지 않는 이유가 그것이다.
///
/// ## 첫소리로도 찾는다
///
/// 「ㅈㅂㄱ」가 「장보기」를 찾는다. 규칙은 `HangulInitials` 에 있고 빠른
/// 입력도 같은 것을 쓴다 — 찾는 상자가 둘인데 한쪽에서만 되면 사람은
/// 어느 쪽에서 되는지를 외워야 한다.
///
/// 뷰 밖의 순수 함수인 이유는 `DrawerContents` 와 같다. **거르기가 한 칸
/// 어긋나면 종이가 없는 것으로 보인다** — 그리고 이 화면에서 가장 비싼 고장이
/// 바로 그것이다. 그림으로는 「없는 것」과 「안 찾아진 것」이 구별되지 않는다.
enum DrawerSearch {

    /// 한글 첫소리 규칙은 빠른 입력과 나눠 쓴다 (`HangulInitials`).
    /// 서랍만의 것이 아니게 된 뒤에도 이 이름을 남긴 이유는 부르는 곳이
    /// 「서랍의 찾기」를 뜻하기 때문이다 — 규칙은 하나, 자리는 둘.
    static func normalize(_ text: String) -> String { HangulInitials.normalize(text) }

    static func initials(of text: String) -> String { HangulInitials.initials(of: text) }

    static func isInitialsQuery(_ query: String) -> Bool { HangulInitials.isInitialsQuery(query) }

    /// 이 종이가 질의에 걸리는가. **제목과 본문을 함께 본다** — 사람은 제목을
    /// 기억하지 못하는 만큼이나 본문의 한 낱말을 기억한다.
    static func matches(_ memo: Memo, query: String) -> Bool {
        HangulInitials.matches(memo.title + "\n" + memo.body, query: query)
    }

    /// 걸리는 것만 남긴다. **차례는 건드리지 않는다** — 서랍만 다른 차례로
    /// 늘어놓으면 같은 메모를 두 곳에서 다르게 그리는 일이 된다 (§14.10).
    static func filter(_ memos: [Memo], query: String) -> [Memo] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return memos }
        return memos.filter { matches($0, query: trimmed) }
    }

    /// 찾은 결과를 **한 줄로 말한다** — 몇 장이 걸렸는가.
    ///
    /// 두 경우에 아무 말도 하지 않는다.
    ///
    /// - **찾는 중이 아닐 때.** 거를 것이 없으면 셀 것도 없다.
    /// - **한 장도 못 찾았을 때.** 그 말은 무더기가 있던 자리에서 더 크게,
    ///   더 자세히 한다 (`DrawerView.empty` — 「서랍에는 11장이 들어 있습니다」).
    ///   같은 말을 한 화면에서 두 번 하면 둘 다 배경이 된다.
    ///
    /// 못 찾았다는 말 **자체**는 반드시 한다. 조용히 빈 서랍을 보여주면 사람은
    /// 그것을 «서랍이 비었다» 로 읽고, 그것이 이 화면에서 가장 비싼 오해다
    /// (`DrawerContents`). 여기서 하지 않을 뿐 어디선가는 한다.
    static func summary(query: String, found: Int) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, found > 0 else { return nil }
        return "\(found)장"
    }
}
