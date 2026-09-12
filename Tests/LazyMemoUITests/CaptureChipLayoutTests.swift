import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 날짜 칩이 뜰 때 상자가 제자리에 있는지.
///
/// 사용자가 겪은 결함: "내일"·"오늘" 을 치면 날짜 칩이 뜨면서 **상자가 위로
/// 올라가고 윗부분이 가려졌다.** 두 가지가 겹쳐 있었다.
///
/// 1. 창을 다시 재는 일을 검색 결과가 돌아올 때(120ms)에 얹어 두었다. 칩은
///    타자와 함께 즉시 뜨므로 그동안 창은 내용보다 작은 채였고, 넘치는 내용이
///    창 밖으로 밀려나 잘렸다.
/// 2. 크기를 바꾸고 나서 자리를 옮겼다. `setContentSize` 는 창의 **아래쪽**
///    모서리를 붙잡으므로, 커지는 순간 상자가 메뉴바를 파고들었다가 되돌아왔다.
///
/// 그래서 여기서 재는 것은 둘이다 — **창이 내용을 다 담는가**, 그리고
/// **아이콘 밑을 벗어나지 않는가.** 검색을 기다리지 않고 확인한다.
@MainActor
@Suite("빠른 입력 — 날짜 칩이 떠도 자리를 지킨다")
struct CaptureChipLayoutTests {
    private func makeController() throws -> (QuickCaptureController, NSRect) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-chip-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()

        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: LayoutStore(location: paths.layout),
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        let controller = QuickCaptureController(store: store, windows: windows)

        // 메뉴바 아이콘 흉내 — 화면 위쪽 끝의 작은 사각형.
        let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let anchor = NSRect(x: screen.midX, y: screen.maxY, width: 24, height: 22)
        controller.anchorProvider = { anchor }
        return (controller, anchor)
    }

    @Test("날짜 칩이 떠도 상자가 내용을 다 담는다 — 검색을 기다리지 않고")
    func theBoxGrowsWithTheChip() throws {
        let (controller, _) = try makeController()
        controller.resize()
        let before = controller.placement

        controller.typeForTesting("내일")
        let after = controller.placement

        // 칩이 실제로 자리를 차지했는지 먼저 확인한다. 안 컸다면 이 시험은
        // 아무것도 재지 못한 것이다.
        #expect(after.contentHeight > before.contentHeight)
        // 그리고 창이 그만큼 따라왔는지. 이것이 안 되면 윗부분이 잘린다.
        #expect(after.frame.height >= after.contentHeight - 0.5)
    }

    @Test("칩이 떠도 아이콘 밑을 벗어나지 않는다 — 메뉴바를 파고들지 않는다")
    func theBoxStaysUnderTheIcon() throws {
        let (controller, anchor) = try makeController()
        controller.resize()

        controller.typeForTesting("내일 오후 3시 치과")

        let placed = controller.placement
        // 커진 만큼 아래로 자라야 한다. 위로 자라면 메뉴바에 먹힌다.
        #expect(placed.frame.maxY <= anchor.minY)
        #expect(placed.frame.height >= placed.contentHeight - 0.5)
    }

    @Test("크기와 자리를 한 번에 정한다 — 위로 튀었다 돌아오는 중간이 없다")
    func sizeAndPositionLandTogether() {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: QuickCaptureController.width, height: 96)
        )
        let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let anchor = NSRect(x: screen.midX, y: screen.maxY, width: 24, height: 22)

        panel.moveToCaptureAnchor(below: anchor, contentHeight: 96)
        let before = panel.frame

        panel.moveToCaptureAnchor(below: anchor, contentHeight: 124)
        let after = panel.frame

        // 한 번의 호출로 커지고 또 제자리에 있다.
        #expect(after.height == 124)
        #expect(after.maxY == before.maxY)
    }

    @Test("칩이 사라지면 상자도 도로 줄어든다")
    func theBoxShrinksBackWithoutTheChip() throws {
        let (controller, _) = try makeController()
        // 빈 화면에는 검색 바로가기가 있으므로 같은 일반 입력 상태와 비교한다.
        controller.resize()
        controller.typeForTesting("치과")
        let plain = controller.placement.frame.height

        controller.typeForTesting("내일")
        let withChip = controller.placement.frame.height
        #expect(withChip > plain)

        controller.typeForTesting("치과")
        #expect(controller.placement.frame.height == plain)
    }
}
