import AppKit
import Carbon.HIToolbox

/// 전역 단축키 한 벌 — 키와 보조키.
///
/// Carbon 의 날 숫자를 그대로 들고 다니면 설정 파일에도, 화면 표기에도,
/// 등록에도 같은 숫자가 흩어진다. 한 값으로 묶어 두면 "무엇이 기본인가" 와
/// "어떻게 보이는가" 를 한 곳에서 답할 수 있다.
struct Hotkey: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// 기본 조합 ⌥⌘N (빠른 입력 상자 열기).
    static let standard = Hotkey(
        keyCode: UInt32(kVK_ANSI_N),
        modifiers: UInt32(optionKey | cmdKey)
    )

    /// 클립보드 원키 즉시 캡처 ⌥⌘V.
    static let paste = Hotkey(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(optionKey | cmdKey)
    )

    /// 지금 여기 ⌥⌘L.
    static let here = Hotkey(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(optionKey | cmdKey)
    )

    /// 보조키가 하나도 없으면 전역 단축키로 쓸 수 없다 — 글자 하나가
    /// 어느 앱에서든 가로채이면 타자를 칠 수가 없다.
    var isUsable: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey | shiftKey) != 0
    }

    // MARK: 표기

    /// ⌥⌘N 처럼 사람이 읽는 표기.
    var displayName: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + Self.keyName(keyCode)
    }

    /// 메뉴 항목 오른쪽에 조합을 적기 위한 값.
    ///
    /// 전역 등록은 Carbon 이 이미 하고 있으므로 이것은 **표기 전용**이다.
    /// 상태 항목 메뉴는 메인 메뉴에 걸리지 않아 열려 있는 동안에만 살아 있고,
    /// 그동안 같은 키를 누르는 것은 어차피 같은 일을 한다.
    ///
    /// 이름이 한 글자가 아닌 키(⏎·esc·F1…)는 `nil` 이다 — 메뉴가 기대하는
    /// 문자 표현이 따로 있어, 어설프게 넣으면 엉뚱한 기호가 찍힌다.
    var menuKeyEquivalent: (key: String, modifiers: NSEvent.ModifierFlags)? {
        let name = Self.keyName(keyCode)
        guard name.count == 1, let scalar = name.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(scalar)
        else { return nil }

        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return (name.lowercased(), flags)
    }

    /// AppKit 이벤트의 보조키를 Carbon 것으로 옮긴다. 등록은 Carbon 이 하고
    /// 입력은 AppKit 으로 받으므로 이 변환이 반드시 한 번 필요하다.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// 키 이름. 표에 없는 키는 번호로 보인다 — 틀린 이름을 보여 주는 것보다 낫다.
    private static func keyName(_ code: UInt32) -> String {
        if let name = names[Int(code)] { return name }
        return L("키\(Int(code))")
    }

    private static let names: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_Space: "Space", kVK_Return: "⏎", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_Escape: "esc", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        kVK_ANSI_Grave: "`",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}
