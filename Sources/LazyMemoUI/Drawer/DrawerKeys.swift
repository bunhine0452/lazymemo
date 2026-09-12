import AppKit

/// 서랍의 **키보드 문법** — 어느 키가 무슨 뜻인가.
///
/// ## 왜 뷰 밖의 순수 함수인가
///
/// **키가 어디로 가는지는 화면에 안 보인다** (§14.9). ↑를 눌렀을 때 무더기가
/// 한 장 올라가는지, 아니면 그 키가 찾기 상자로 흘러가 아무 일도 안 일어나는지는
/// 렌더에도 캡처에도 남지 않는다. 그래서 «키 → 뜻» 을 여기 한 곳에 모아 두고
/// 시험이 직접 묻는다 (`QuickCaptureController.handles` 와 같은 셈이다).
///
/// ## 규칙 하나: 글자는 건드리지 않는다
///
/// 찾기는 진짜 글 상자가 맡는다 (`DrawerView.searchField`). 한글은 조합
/// 입력이라 날 키 이벤트를 가로채 글자를 모으면 **「장」을 치는데 「wkd」가
/// 쌓인다.** 그래서 여기서 맡는 것은 **조합에 쓰이지 않는 키뿐**이다 —
/// 화살표, Return, Escape, 그리고 ⌘ 조합.
enum DrawerKeys {

    /// 키 하나가 서랍에 시키는 일.
    enum Intent: Equatable {
        /// 무더기를 훑는다. `-1` 이 위.
        case move(Int)
        /// 짚은 것을 원래 크기로 펼친다 / 펼친 것을 도로 접는다.
        case zoom
        /// 짚은 것을 바탕화면으로 되돌린다.
        case takeOut
        /// 짚은 것을 지운다.
        case delete
        /// 짚은 것을 고르기에 넣거나 뺀다.
        case pick
        /// 찾기 상자로 간다.
        case search
        /// 한 겹 되돌린다 — 고르기 → 찾기 → 펼친 종이 → 서랍.
        case back
        /// 가려진 장을 더 펼친다.
        case revealMore
    }

    /// 이 키를 서랍이 맡는가, 맡는다면 무슨 뜻인가.
    ///
    /// - Parameters:
    ///   - characters: `NSEvent.charactersIgnoringModifiers`.
    ///   - modifiers: 눌린 조합키.
    ///   - isEditing: 지금 찾기 상자에 커서가 있는가. **글자 키를 삼키지
    ///     않기 위해** 필요하다 — 상자에 커서가 있으면 ⌘ 없는 글자는 전부
    ///     상자 몫이다.
    static func intent(
        characters: String?,
        modifiers: NSEvent.ModifierFlags,
        isEditing: Bool
    ) -> Intent? {
        let command = modifiers.contains(.command)
        // ⌥·⌃ 조합은 손대지 않는다 — 시스템과 입력기의 몫이다.
        guard !modifiers.contains(.control), !modifiers.contains(.option) else { return nil }

        if command {
            switch characters?.lowercased() {
            case "f": return .search
            case "\u{8}", "\u{7F}": return .delete   // ⌘⌫
            case "\r": return .takeOut               // ⌘↩
            default: return nil
            }
        }

        switch characters {
        case "\u{F700}": return .move(-1)            // ↑
        case "\u{F701}": return .move(1)             // ↓
        case "\u{1B}": return .back                  // esc
        case "\r": return .zoom
        default: break
        }

        // 여기부터는 글자 키다. 찾는 중이면 전부 상자 몫이다.
        guard !isEditing else { return nil }
        switch characters {
        case " ": return .pick
        case "\u{F729}": return .move(-999)          // Home — 맨 위로
        case "\u{F72B}": return .move(999)           // End — 맨 아래로
        case "+", "=": return .revealMore
        default: return nil
        }
    }
}
