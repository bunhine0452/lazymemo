import XCTest

/// 위젯이 두드리는 주소 — `lazymemo://memo/<id>` 는 그 메모를 시트로, `lazymemo://write` 는 펜을.
///
/// 시험은 밖에서 주소를 열므로 시스템이 「'lazymemo'에서 열겠습니까?」를 묻는다 — 위젯에서는 묻지 않는다.
/// 그 창은 스프링보드의 것이라 거기서 「열기」를 누른다.
final class DeepLinkTests: XCTestCase {
    private var root: URL!
    private static let memoID = "01M26ZN0M000000000000000AB"

    override func setUp() {
        continueAfterFailure = false
        root = URL(filePath: "/tmp/lazymemo-uitest-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testMemoLinkOpensThatMemoAsASheet() throws {
        try seed()
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["capture"].waitForExistence(timeout: 10), "펜이 없다")

        open("lazymemo://memo/\(Self.memoID)")

        // 시트의 「닫기」와 본문 — 알림·Spotlight 와 같은 시트다 (`HomeView`).
        XCTAssertTrue(app.buttons["닫기"].waitForExistence(timeout: 8), "그 메모가 시트로 떠야 한다")
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue((app.textViews.firstMatch.value as? String ?? "").contains("치과 예약"), "그 메모여야 한다")
        app.buttons["닫기"].tap()
        XCTAssertFalse(app.buttons["닫기"].waitForExistence(timeout: 1), "닫혀야 한다")
    }

    func testWriteLinkRaisesThePen() throws {
        try seed()
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10), "펜이 없다")
        // 켜면 펜에 키보드가 올라와 있다 — 먼저 내려 두어야 「올라온다」를 볼 수 있다.
        dismissKeyboard(app)
        XCTAssertEqual(app.keyboards.count, 0, "키보드를 내리지 못했다")

        open("lazymemo://write")

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8), "펜이 올라와야 한다")
        XCTAssertTrue(capture.exists)
    }

    // MARK: 도구

    /// 밖에서 주소를 열고, 시스템이 물으면 「열기」.
    private func open(_ url: String) {
        XCUIDevice.shared.system.open(URL(string: url)!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["열기"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        app.launchArguments += ["-tutorialSeen", "YES", "-recall.notifications.enabled", "NO", "-now-seen", "{}"]
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func seed() throws {
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        let text = "---\nid: \(Self.memoID)\ncreated: 2026-09-11T10:00:00+09:00\nupdated: 2026-09-11T10:00:00+09:00\nat: 2026-09-15T15:00:00+09:00\ntags: []\ncolor: blue\npinned: false\n---\n치과 예약 — 강남역 3번 출구\n"
        try text.write(to: notes.appending(path: Self.memoID + ".md"), atomically: true, encoding: .utf8)
    }
}
