import AppKit

/// 서랍의 **키보드 문법** — 어느 키가 무슨 뜻인가.
///
/// ## 왜 뷰 밖의 순수 함수인가
///
/// **키가 어디로 가는지는 화면에 안 보인다** (§14.9). ↑를 눌렀을 때 목록이
/// 한 줄 올라가는지, 아니면 그 키가 찾기 상자로 흘러가 아무 일도 안 일어나는지는
/// 렌더에도 캡처에도 남지 않는다. 그래서 «키 → 뜻» 을 여기 한 곳에 모아 두고
/// 시험이 직접 묻는다 (`QuickCaptureController.handles` 와 같은 셈이다).
///
/// ## 규칙 하나: 글자는 건드리지 않는다
///
/// 찾기와 폴더 이름은 진짜 글 상자가 맡는다 (`DrawerView`). 한글은 조합
/// 입력이라 날 키 이벤트를 가로채 글자를 모으면 **「장」을 치는데 「wkd」가
/// 쌓인다.** 그래서 여기서 맡는 것은 **조합에 쓰이지 않는 키뿐**이다 —
/// 화살표, Return, Escape, Tab, 그리고 ⌘ 조합.
///
/// ## 규칙 둘: 이미 아는 키를 이미 아는 뜻으로 (§16.12)
///
/// ↩ 는 **꺼내기**다 — 줄을 누르는 것과 같은 일이고, 목록에서 ↩ 는 어디서나
/// «그것을 연다» 다. Space 는 **펼쳐 보기** — Finder 의 훑어보기. ⇧↑↓ 는
/// **고르며 훑기** — Finder 가 고름을 늘리는 손짓. 이 앱만의 뜻을 익숙한
/// 키에 얹지 않는다 (HIG Gestures: "avoid using a familiar gesture… to
/// perform an action that's unique to your app").
enum DrawerKeys {

    /// 키 하나가 서랍에 시키는 일.
    enum Intent: Equatable {
        /// 목록을 훑는다. `-1` 이 위.
        case move(Int)
        /// 훑으면서 **고른다** — ⇧↑↓. Finder 가 ⇧ 화살표로 고름을 늘리는 그 손짓.
        case extend(Int)
        /// 짚은 줄을 펼쳐 본다 / 펼친 줄을 도로 접는다. **Space** — Finder 의 훑어보기.
        case zoom
        /// 짚은 것을 바탕화면으로 되돌린다. **↩** — 줄을 누르는 것과 같은 일이다 (§16.12).
        case takeOut
        /// 짚은 것을 지운다.
        case delete
        /// 찾기 상자로 간다.
        case search
        /// 한 겹 되돌린다 — 고르기 → 찾기 → 펼친 줄 → 짚은 자리 → 폴더 → 서랍.
        case back
        /// 옆 폴더로. `1` 이 오른쪽.
        case folder(Int)
    }

    /// 이 키를 서랍이 맡는가, 맡는다면 무슨 뜻인가.
    ///
    /// - Parameters:
    ///   - characters: `NSEvent.charactersIgnoringModifiers`.
    ///   - modifiers: 눌린 조합키.
    ///   - isEditing: 지금 글 상자(찾기·폴더 이름)에 커서가 있는가. **글자
    ///     키를 삼키지 않기 위해** 필요하다 — 상자에 커서가 있으면 ⌘ 없는
    ///     글자는 전부 상자 몫이다.
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
            // ⌘↩ 도 꺼낸다 — ↩ 가 펼치기였던 판의 손버릇을 끊지 않는다.
            case "\r": return .takeOut
            default: return nil
            }
        }

        let shift = modifiers.contains(.shift)
        switch characters {
        case "\u{F700}": return shift ? .extend(-1) : .move(-1)    // ↑ · ⇧↑
        case "\u{F701}": return shift ? .extend(1) : .move(1)      // ↓ · ⇧↓
        case "\u{1B}": return .back                  // esc
        // Tab 은 글 상자 안에서도 서랍 몫이다 — 한 줄짜리 상자에서 Tab 은
        // 하는 일이 없고, 폴더를 옮겨 다니는 손이 상자에서 나오지 않아도 된다.
        case "\t": return .folder(1)
        case "\u{19}": return .folder(-1)             // ⇧Tab
        // ↩ 는 찾는 중에도 서랍 몫이다 — 치고, ↓ 로 짚고, ↩ 로 **꺼내는** 것이
        // 한 손에서 끝나야 한다. 줄을 누르는 것과 같은 일이라 같은 키다 (§16.12).
        // 겨눈 줄이 없으면 모델이 흘려보내므로(`DrawerModel.handle`) 폴더
        // 이름을 적고 누르는 ↩ 는 상자에 닿는다.
        case "\r": return .takeOut
        default: break
        }

        guard !isEditing else { return nil }
        switch characters {
        // Space 는 **펼쳐 보기**다 — Finder 의 훑어보기(Quick Look)와 같은 키.
        // 앞선 판은 고르기였는데, 그것은 이 앱만의 뜻이라 배워야 했다.
        case " ": return .zoom
        case "\u{F729}": return .move(-999)          // Home — 맨 위로
        case "\u{F72B}": return .move(999)           // End — 맨 아래로
        default: return nil
        }
    }
}
