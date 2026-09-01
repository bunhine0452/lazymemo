/// 서랍이 **읽기만 하는 자리**에서 글을 어떻게 적는가.
///
/// 종이의 편집기는 마크다운을 글자를 바꾸지 않고 꾸민다 (§15.1) — 체크상자는
/// 상자로 그려지고 `- [x]` 라는 글자는 화면에 없다. 서랍의 종이는 그 편집기를
/// 들고 있지 않으므로(읽기만 한다) 그대로 두면 **같은 메모가 두 곳에서 다른
/// 물건으로 보인다** (§14.10 — 두 곳에서 같은 것을 다르게 그리면 사람은 그것을
/// 두 개로 배운다).
///
/// 그래서 여기서 최소한만 바꿔 적는다. **아는 것만 바꾼다** — 체크상자와 그
/// 앞의 목록 기호뿐이고, 나머지 줄은 원문 그대로다. 파일이 정본인 앱에서
/// 화면이 아는 척 고쳐 쓰면 사람이 파일을 열었을 때 다른 글이 나온다 (D4).
///
/// 뷰 밖의 순수 함수인 이유: 한 글자 어긋난 변환은 **그림에서 안 보인다** —
/// 「☑ 우유」와 「☑우유」의 차이를 렌더에서 판별할 수 없다.
enum DrawerText {

    /// 한 줄에서 목록 기호와 체크상자를 사람이 읽는 모양으로 바꾼다.
    static func plain(_ line: some StringProtocol) -> String {
        let text = String(line)
        let body = text.drop { $0 == " " || $0 == "\t" }
        let indent = String(text.prefix(text.count - body.count))

        var rest = String(body)
        for marker in ["- ", "* ", "+ "] where rest.hasPrefix(marker) {
            rest.removeFirst(marker.count)
            break
        }

        if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
            return indent + "☑ " + String(rest.dropFirst(4))
        }
        if rest.hasPrefix("[ ] ") {
            return indent + "☐ " + String(rest.dropFirst(4))
        }
        // 체크상자가 아니면 손대지 않는다 — 목록 기호도 그대로 남는다.
        return text
    }
}
