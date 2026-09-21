// 「종이 보기」(⌥⌘P) 실화면 검증 드라이버 — 합성 키·마우스 이벤트를 넣고 창 레벨로 확인한다.
//
//   swift scripts/verify-peek.swift <pid>
//
// 창 레벨은 CGWindowListCopyWindowInfo 로 권한 없이 읽힌다. 키·마우스는 CGEvent 로 넣으므로
// 이 셸에 손쉬운 사용(Accessibility) 권한이 있어야 한다 (verify-drawer-mouse.sh 와 같다).
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count > 1, let pid = Int(args[1]) else {
    FileHandle.standardError.write(Data("사용법: swift scripts/verify-peek.swift <pid>\n".utf8))
    exit(2)
}
let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1   // DesktopLevelWindow.desktopLevel
let focusedLevel = Int(CGWindowLevelForKey(.floatingWindow)) - 1      // DesktopLevelWindow.focusedLevel

struct Paper { let number: Int; let level: Int; let bounds: CGRect }

/// 이 앱의 종이 — 바탕에 눕거나 앞에 선 것. 화면에 있는 차례(앞에서 뒤)로.
func papers() -> [Paper] {
    let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return raw.compactMap { entry in
        guard entry[kCGWindowOwnerPID as String] as? Int == pid,
              let number = entry[kCGWindowNumber as String] as? Int,
              let level = entry[kCGWindowLayer as String] as? Int,
              let dict = entry[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
              bounds.width > 80, bounds.height > 60, level == desktopLevel || level == focusedLevel
        else { return nil }
        return Paper(number: number, level: level, bounds: bounds)
    }
}
func allUp() -> Bool { let w = papers(); return !w.isEmpty && w.allSatisfy { $0.level == focusedLevel } }
func allDown() -> Bool { let w = papers(); return !w.isEmpty && w.allSatisfy { $0.level == desktopLevel } }

func hotkey() {   // ⌥⌘P
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: 35, keyDown: true)!
    let up = CGEvent(keyboardEventSource: source, virtualKey: 35, keyDown: false)!
    down.flags = [.maskCommand, .maskAlternate]
    up.flags = [.maskCommand, .maskAlternate]
    down.post(tap: .cghidEventTap)
    usleep(60_000)
    up.post(tap: .cghidEventTap)
}
func click(_ point: CGPoint) {
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
    usleep(120_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
    usleep(80_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func waitFor(_ timeout: Double, _ ok: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end { if ok() { return true }; usleep(100_000) }
    return ok()
}
var failed = false
func check(_ condition: Bool, _ message: String) {
    print((condition ? "  ✓ " : "  ✗ ") + message)
    if !condition { failed = true }
}

print("▸ 시작 — 종이가 바탕화면 높이에 눕는가")
check(waitFor(8) { papers().filter { $0.level == desktopLevel }.count >= 2 }, "종이 두 장이 바탕화면 높이에 있다")

print("▸ ⌥⌘P — 전부 앞에 서고 4초 뒤 스스로 눕는가")
let pressed = Date()
hotkey()
check(waitFor(2, allUp), "누르자 종이 전부가 앞에 섰다 (다른 앱 창 위)")
let settledAfter: Double? = waitFor(7, allDown) ? Date().timeIntervalSince(pressed) : nil
check(settledAfter != nil, "스스로 내려앉았다" + (settledAfter.map { String(format: " (%.1f초 뒤)", $0) } ?? " — 7초 안에 내려앉지 않음"))

print("▸ 다시 누르면 곧바로 눕는가")
hotkey()
usleep(700_000)
check(allUp(), "첫 누름에 섰다")
hotkey()
check(waitFor(1.5, allDown), "둘째 누름에 곧바로 내려앉았다 (4초를 기다리지 않음)")

print("▸ 서 있는 동안 종이 하나를 누르면 그것만 남는가")
usleep(500_000)
hotkey()
usleep(700_000)
let standing = papers().filter { $0.level == focusedLevel }   // 앞에서 뒤 차례 — 첫째가 맨 앞
check(standing.count >= 2, "서 있는 종이 \(standing.count)장")
if let front = standing.first {
    click(CGPoint(x: front.bounds.midX, y: front.bounds.midY))   // 맨 앞 종이의 한가운데 — 다른 종이가 덮지 못하는 자리
    _ = waitFor(6) { papers().filter { $0.level == desktopLevel }.count >= standing.count - 1 }
    let after = papers()
    check(after.first { $0.number == front.number }?.level == focusedLevel, "누른 종이는 4초 뒤에도 앞에 남았다")
    check(after.filter { $0.number != front.number }.allSatisfy { $0.level == desktopLevel }, "누르지 않은 종이는 내려앉았다")
}
print(failed ? "✗ 종이 보기" : "✓ 종이 보기")
exit(failed ? 1 : 0)
