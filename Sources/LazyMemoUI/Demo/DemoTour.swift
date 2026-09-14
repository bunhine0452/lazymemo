import AppKit
import LazyMemoCore
import SwiftUI

/// 앱이 **스스로 한 바퀴 돈다** — 소개 영상을 찍기 위한 주행 (`scripts/record-demo.sh`).
///
/// 화면 기록으로 찍는 것은 실제 창이다. 다만 손은 사람이 아니라 이 타입이
/// 움직인다: 빠른 입력에 글자를 한 자씩 넣고, 확정하고, 종이를 서랍에 날려
/// 넣고, 폴더를 넘겨 본다. 포인터가 필요한 손짓(끌어다 놓기·손 얹기)은 흉내
/// 내지 않는다 — 앱이 실제로 하는 일만 보여 준다.
///
/// **무대는 화면의 한 구역이다** (`region`). 그 구역에 바탕을 깔고 창을 전부
/// 그 안에 세우므로, 녹화는 그 구역만 잘라도 된다. 임시 Vault 를 쓰므로
/// 실제 메모는 건드리지 않는다.
@MainActor
final class DemoTour {
    /// 무대 — AppKit 좌표 (왼쪽 아래 원점).
    let region: CGRect

    private let store: MemoStore
    private let layouts: LayoutStore
    private let settings: SettingsStore
    private let windows: NoteWindowManager
    private let capture: QuickCaptureController
    private let calendar: CalendarWindowController
    private let drawer: DrawerWindowController
    private var backdrop: NSPanel?

    init(
        region: CGRect, store: MemoStore, layouts: LayoutStore, settings: SettingsStore,
        windows: NoteWindowManager, capture: QuickCaptureController,
        calendar: CalendarWindowController, drawer: DrawerWindowController
    ) {
        self.region = region
        self.store = store
        self.layouts = layouts
        self.settings = settings
        self.windows = windows
        self.capture = capture
        self.calendar = calendar
        self.drawer = drawer
    }

    /// `LAZYMEMO_DEMO=x,y,w,h` — AppKit 좌표의 무대.
    static func region(from text: String) -> CGRect? {
        let parts = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    // MARK: 무대 세우기

    /// 창을 세우기 **전에** 부른다 — 메모와 자리를 먼저 심어야 창이 그 자리에 선다.
    func seed() async {
        settings.update { $0.folders = [L("장보기"), L("읽을 것"), L("집")] }
        drawer.model.adoptFolders([L("장보기"), L("읽을 것"), L("집")])

        let onDesk: [(String, MemoColor)] = [
            (L("장보기 목록\n- [x] 우유\n- [x] 계란\n- [ ] 세제\n- [ ] 식빵"), .green),
            (L("읽다 만 것 — 「종이의 물성」\n3장까지 읽었다. 4장은 접는 법."), .blue),
        ]
        let filed: [(String, MemoColor, String?)] = [
            (L("환불 신청 번호\n8821-0043"), .yellow, nil),
            (L("겨울옷 정리\n패딩 세탁 맡기기"), .purple, L("집")),
            (L("이사 견적 세 군데\n한아름 / 무지개 / 다섯별"), .gray, L("집")),
            (L("도서관 반납\n「게으름의 기술」"), .yellow, L("읽을 것")),
            (L("명함 사진 찍어 두기"), .pink, nil),
            (L("전구 40W 두 개"), .yellow, L("장보기")),
            (L("커튼 세탁"), .purple, L("집")),
        ]

        // 바탕화면의 종이는 무대 오른쪽 위부터 계단으로 — 새 종이의 첫 자리와
        // 같은 규칙이라, 적은 종이가 그 아래로 자연스럽게 내려앉는다.
        let paper = CGSize(width: 268, height: 196)
        for (index, (body, color)) in onDesk.enumerated() {
            guard let memo = try? await store.create(body: body, color: color) else { continue }
            let origin = CGPoint(
                x: region.maxX - paper.width - 40 - CGFloat(index) * 36,
                y: region.maxY - paper.height - 40 - CGFloat(index) * 236
            )
            layouts.set(WindowLayout(frame: CGRect(origin: origin, size: paper), hidden: false), for: memo.id)
        }
        for (body, color, folder) in filed {
            guard let memo = try? await store.create(body: body, color: color, folder: folder) else { continue }
            layouts.set(
                WindowLayout(frame: CGRect(x: region.midX, y: region.midY, width: 260, height: 200), hidden: true),
                for: memo.id
            )
        }

        // 서랍 탭은 무대 왼쪽 아래, 달력은 왼쪽 위 — 실제 기본 자리와 같은 배치다.
        layouts.set(
            WindowLayout(frame: CGRect(
                x: region.minX + 36, y: region.minY + 36,
                width: DrawerGeometry.closedSize.width, height: DrawerGeometry.closedSize.height
            ), hidden: false),
            forKey: "drawer"
        )
        layouts.set(
            WindowLayout(frame: CGRect(
                x: region.minX + 36, y: region.maxY - 470 - 36, width: 320, height: 470
            ), hidden: true),
            forKey: "calendar"
        )
        layouts.flush()

        windows.stage = region
        drawer.placeForDemo(at: CGPoint(x: region.minX + 36, y: region.minY + 36))
        // 무대의 창은 남의 창과 위젯 **위에** 선다 — 안 그러면 찍히는 것이 그것들이다.
        DesktopLevelWindow.stageLevel = Self.restingLevel
        raiseBackdrop()
        // 빠른 입력은 무대 위쪽 한가운데에 매단다 — 메뉴바 아이콘은 무대 밖이다.
        let anchor = CGRect(x: region.midX - 10, y: region.maxY - 6, width: 20, height: 6)
        capture.anchorProvider = { anchor }
    }

    // MARK: 한 바퀴

    /// 무대에서 종이가 눕는 자리 — 일반 창(0)보다 위, 빠른 입력(`.floating` = 3)보다 아래.
    ///
    /// `.floating` 의 값은 3 이다. 거기서 넷을 빼면 일반 창 **아래**로 떨어져 남의
    /// 창이 그대로 찍힌다 — 첫 녹화가 그랬다. 사이에 있는 칸은 1 과 2 뿐이다.
    private static let backdropLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
    private static let restingLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 2)

    func run() async {
        // 포인터는 무대 밖으로 — 화면 기록에 화살표가 남는다.
        if let screen = NSScreen.main {
            CGWarpMouseCursorPosition(CGPoint(x: 6, y: screen.frame.height - 6))
        }
        await pause(1.4)
        // 1. 빠른 입력 — 날짜를 앱이 읽는다.
        capture.show()
        await pause(0.7)
        await type(L("내일 오후 3시 치과 예약"))
        await pause(1.4)
        capture.commitForDemo()
        await pause(2.4)

        // 2. 날짜 없는 한 줄 — 종이가 된다.
        capture.show()
        await pause(0.6)
        await type(L("우산 새로 사기"))
        await pause(0.7)
        capture.commitForDemo()
        await pause(1.8)

        // 3. 그 종이를 서랍에 넣는다 — 날아 들어간다.
        guard let umbrella = store.memos.first(where: { $0.title == L("우산 새로 사기") }) else { return }
        drawer.fileForDemo(umbrella.id)
        await pause(1.5)

        // 4. 서랍을 펼친다 — 찾기·폴더·목록.
        drawer.model.setOpen(true)
        await pause(1.8)

        // 5. 폴더 하나만 본다.
        drawer.model.selectedFolder = L("집")
        await pause(1.5)
        if let first = drawer.model.shown.first?.id {
            drawer.model.zoom(first)
            await pause(1.8)
            drawer.model.shrink()
            await pause(0.5)
        }

        // 6. 전체로 돌아와 두 장을 골라 폴더로 옮긴다.
        drawer.model.selectedFolder = nil
        await pause(0.8)
        let loose = drawer.model.shown.filter { $0.folder == nil }.prefix(2).map(\.id)
        for id in loose {
            drawer.model.pick(id)
            await pause(0.5)
        }
        await pause(0.9)
        drawer.model.movePicked(to: L("장보기"))
        await pause(1.4)

        // 7. 새 폴더.
        drawer.model.isNamingFolder = true
        await pause(1.0)
        drawer.model.createFolder(L("여행"))
        await pause(1.3)

        // 8. 한 장을 도로 꺼낸다 — 바탕화면으로 돌아간다.
        drawer.model.selectedFolder = nil
        await pause(0.6)
        if let back = drawer.model.shown.first(where: { $0.title == L("우산 새로 사기") })?.id {
            drawer.model.takeOut(back)
            await pause(1.8)
        }
        drawer.model.setOpen(false)
        await pause(1.4)
    }

    // MARK: 스토어 스크린샷

    /// 장면을 하나씩 세우고 무대를 찍는다 (`scripts/store-shots.sh`). 영상이 아니라
    /// **정지한 장면 넷**이다 — 빠른 입력이 날짜를 읽는 순간, 종이와 달력, 서랍,
    /// 서랍의 폴더 하나. 찍는 것은 `run()` 과 같은 실제 창이다. 마지막 한 장은
    /// 같은 무대를 어두운 모양으로 — 시스템 설정을 건드리지 않고 이 앱만 바꾼다.
    func shots(into directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let screen = NSScreen.main {
            CGWarpMouseCursorPosition(CGPoint(x: 6, y: screen.frame.height - 6))
        }
        // 달력에 보일 일정 — 오늘과 이번 주. 빠른 입력의 「치과 예약」은 장면 1 이 적는다.
        let today = CalendarDate(Date())
        let dated: [(String, Int, Int)] = [
            (L("팀 회의\n분기 계획 초안 가져가기"), 0, 10),
            (L("저녁 약속 — 현진\n망원동 파스타집"), 0, 19),
            (L("전기 요금 납부"), 3, 9),
            (L("도서관 반납\n「게으름의 기술」"), 6, 14),
        ]
        for (body, offset, hour) in dated {
            let day = today.adding(days: offset)
            let at = Calendar.current.date(from: DateComponents(
                year: day.year, month: day.month, day: day.day, hour: hour
            ))
            guard let memo = try? await store.create(body: body, due: day, at: at) else { continue }
            layouts.set(
                WindowLayout(frame: CGRect(x: region.midX, y: region.midY, width: 260, height: 200), hidden: true),
                for: memo.id
            )
        }
        await pause(1.2)

        // 1. 빠른 입력이 날짜를 읽는다.
        capture.show()
        await pause(0.7)
        await type(L("내일 오후 3시 치과 예약"))
        await snap("capture", into: directory)
        capture.commitForDemo()
        await pause(1.6)

        // 2. 종이 한 장이 더 서고, 달력이 열려 있다. 빠른 입력으로 적으면 새 종이의
        //    첫 자리(계단 꼭대기)가 `seed` 의 첫 종이와 겹치므로, 자리를 정해서 세운다.
        if let umbrella = try? await store.create(body: L("우산 새로 사기"), color: .yellow) {
            let paper = CGSize(width: 268, height: 196)
            layouts.set(
                WindowLayout(frame: CGRect(
                    x: region.maxX - paper.width - 40 - 72,
                    y: region.maxY - paper.height - 40 - 472,
                    width: paper.width, height: paper.height
                ), hidden: false),
                for: umbrella.id
            )
        }
        await pause(1.2)
        calendar.open()
        await snap("desk", into: directory)

        // 3. 서랍 — 찾기·폴더·목록.
        calendar.close()
        await pause(0.4)
        drawer.model.setOpen(true)
        await snap("drawer", into: directory)

        // 4. 폴더 하나만.
        drawer.model.selectedFolder = L("집")
        await snap("folder", into: directory)
        drawer.model.selectedFolder = nil
        drawer.model.setOpen(false)
        await pause(0.6)

        // 5. 같은 책상, 어두운 모양.
        calendar.open()
        NSApp.appearance = NSAppearance(named: .darkAqua)
        await snap("desk-dark", into: directory)
        NSApp.appearance = nil
        calendar.close()
    }

    /// 무대만 잘라 PNG 로. `screencapture` 는 왼쪽 위 원점이라 세로를 뒤집는다.
    private func snap(_ name: String, into directory: URL) async {
        await pause(1.0)
        guard let screen = NSScreen.main else { return }
        let top = screen.frame.maxY - region.maxY
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x", "-t", "png",
            "-R", "\(Int(region.minX)),\(Int(top)),\(Int(region.width)),\(Int(region.height))",
            directory.appending(path: "\(name).png").path,
        ]
        try? process.run()
        process.waitUntilExit()
        FileHandle.standardError.write(Data("[shots] \(name)\n".utf8))
    }

    /// 사람이 치는 것처럼 한 자씩.
    private func type(_ text: String) async {
        var typed = ""
        for character in text {
            typed.append(character)
            capture.typeForTesting(typed)
            await pause(0.075)
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    /// 무대의 바탕 — 종이 뒤에 깔리는 잔잔한 면. 사람의 바탕화면 대신 찍힌다.
    private func raiseBackdrop() {
        let panel = NSPanel(
            contentRect: region, styleMask: [.borderless], backing: .buffered, defer: false
        )
        panel.level = Self.backdropLevel
        panel.isOpaque = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: DemoBackdrop())
        panel.setFrame(region, display: true)
        panel.orderFront(nil)
        backdrop = panel
    }
}

/// 렌더의 바탕화면 흉내와 같은 결 — 밝은 모드는 옅은 남색, 어두운 모드는 남빛 차콜.
private struct DemoBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.20, green: 0.21, blue: 0.28), Color(red: 0.10, green: 0.10, blue: 0.15)]
                : [Color(red: 0.82, green: 0.85, blue: 0.90), Color(red: 0.66, green: 0.71, blue: 0.80)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
