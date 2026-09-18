// 서랍을 **진짜 마우스**로 검증한다 — 합성 HID 이벤트를 창 서버에 넣는다 (`verify-drawer-mouse.sh`).
//
// `verify-drawer.sh` 는 모델을 직접 밀어 창의 산수만 본다. 잡아서 끌리는지, 눌러서 펼쳐지는지,
// 다른 앱을 누르면 접히는지는 이벤트가 AppKit 을 **실제로** 통과해야 안다 — 2026-09-18 의 고장
// (`performDrag` 가 곧바로 돌아와 잡기만 해도 펼쳐지던 것)은 산수 검증과 정적 렌더를 다 통과했다.
//
//   verify-drawer-mouse <pid> tab       # 탭: 끌기 → 누르기(펼침) → 머리 줄 끌기 → × (접힘)
//   verify-drawer-mouse <pid> summoned  # 펼친 채 앞에 선 판: 머리 줄 끌기 → 바깥 클릭 (접힘)
//
// 이 프로세스(터미널)에 손쉬운 사용 권한이 있어야 이벤트가 들어간다 — 없으면 조용히 버려진다.
import AppKit
import CoreGraphics

setbuf(stdout, nil)   // 파이프로 받아도 줄마다 나온다
let pid = pid_t(CommandLine.arguments[1])!
let scenario = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "tab"
var failed = false

struct Win { let id: Int; let bounds: CGRect }

func windows() -> [Win] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
    return list.compactMap { info in
        guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
              let b = info[kCGWindowBounds as String] as? [String: CGFloat],
              let id = info[kCGWindowNumber as String] as? Int else { return nil }
        return Win(id: id, bounds: CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!))
    }
}

/// 서랍 창 — 닫힌 탭(232×60)이거나 펼친 판(440 너비). 종이(260×200)와 구별된다.
func drawer() -> Win? {
    windows().first { abs($0.bounds.width - 232) < 1 && abs($0.bounds.height - 60) < 1 }
        ?? windows().first { abs($0.bounds.width - 440) < 1 }
}

func post(_ type: CGEventType, at p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func sleepMs(_ ms: Int) { usleep(UInt32(ms) * 1000) }

func wait(_ cond: () -> Bool) -> Bool {
    for _ in 0..<40 { if cond() { return true }; sleepMs(100) }
    return false
}

func report(_ what: String, _ ok: Bool, _ detail: String) {
    print("\(ok ? "✓" : "✗") \(what) — \(detail)")
    if !ok { failed = true }
}

/// 잡아서 (dx, dy) 만큼 끈다. 창이 그만큼 따라왔는지 본다.
func drag(from c: CGPoint, by dx: CGFloat, _ dy: CGFloat, what: String) {
    let before = bounds().origin
    post(.mouseMoved, at: c); sleepMs(150)
    post(.leftMouseDown, at: c); sleepMs(80)
    for i in 1...10 {
        post(.leftMouseDragged, at: CGPoint(x: c.x + dx * CGFloat(i) / 10, y: c.y + dy * CGFloat(i) / 10)); sleepMs(25)
    }
    sleepMs(80)
    post(.leftMouseUp, at: CGPoint(x: c.x + dx, y: c.y + dy)); sleepMs(500)
    guard let after = drawer()?.bounds else { report(what, false, "끌고 나니 서랍 창이 없다"); return }
    let moved = CGPoint(x: after.minX - before.x, y: after.minY - before.y)
    report(what, abs(moved.x - dx) < 4 && abs(moved.y - dy) < 4,
           "Δ\(Int(moved.x)),\(Int(moved.y)) (바란 것 \(Int(dx)),\(Int(dy))) 크기 \(Int(after.width))×\(Int(after.height))")
}

func click(at p: CGPoint) {
    post(.mouseMoved, at: p); sleepMs(150)
    post(.leftMouseDown, at: p); sleepMs(60)
    post(.leftMouseUp, at: p)
}

func bounds() -> CGRect { drawer()?.bounds ?? .zero }
func size() -> String { let b = bounds(); return "\(Int(b.width))×\(Int(b.height))" }
func tabCenter() -> CGPoint { let b = bounds(); return CGPoint(x: b.midX, y: b.midY) }
/// 펼친 판의 머리 줄, 「서랍」 글자 위 — 손잡이가 글자에 가려지지 않는지까지 본다.
func headingTitle() -> CGPoint { let b = bounds(); return CGPoint(x: b.minX + 60, y: b.minY + 26) }
func closeButton() -> CGPoint { let b = bounds(); return CGPoint(x: b.maxX - 24, y: b.minY + 26) }

guard wait({ drawer() != nil }) else { print("✗ 서랍 창을 찾지 못했습니다"); exit(1) }

switch scenario {
case "tab":
    drag(from: tabCenter(), by: 120, 80, what: "탭을 잡아 끌기")
    report("탭 끌기 뒤에도 접힌 채", abs(bounds().width - 232) < 1, size())
    click(at: tabCenter())
    report("탭 누르기 → 펼침", wait { bounds().width > 400 }, size())
    drag(from: headingTitle(), by: -100, -60, what: "펼친 판의 머리 줄(글자 위) 잡아 끌기")
    click(at: closeButton())
    report("× → 접힘", wait { abs(bounds().width - 232) < 1 }, size())
case "summoned":
    drag(from: headingTitle(), by: -100, -60, what: "앞에 선 판의 머리 줄 잡아 끌기")
    // 화면 오른쪽 아래 — 서랍 밖의 남의 창. 앱이 활성을 잃으면 접혀야 한다.
    let screen = NSScreen.screens[0].frame
    click(at: CGPoint(x: screen.width - 30, y: screen.height - 120))
    report("다른 앱 클릭 → 접힘", wait { abs(bounds().width - 232) < 1 }, size())
default:
    print("모르는 시나리오: \(scenario)"); exit(2)
}
exit(failed ? 1 : 0)
