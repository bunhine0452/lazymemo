import XCTest

/// 폰이 **스스로 한 바퀴 돈다** — 소개 영상을 찍기 위한 주행 (`ios/scripts/record-demo.sh`).
/// 맥의 `DemoTour` 자리. `LAZYMEMO_DEMO=1` 일 때만 돌고, 시뮬레이터 화면 기록이 그것을 담는다.
///
/// 손은 XCUITest 가 움직이지만 화면의 것은 전부 진짜다 — 적고, 달력에 남기고, 다시 볼
/// 시각을 정하고, 「지금」에 오르고, 알림을 켜고, 배너를 눌러 그 메모가 열린다.
/// 배너는 스크립트가 `simctl push` 로 넣는다: 이 시험이 `push` 파일에 메모 id 를
/// 적으면 스크립트가 그것을 읽어 보낸다 — 시험은 시뮬레이터 밖의 명령을 못 부른다.
/// `ready`·`done` 파일의 시각으로 스크립트가 영상의 앞뒤를 자른다.
final class DemoTests: XCTestCase {
    private var root: URL!
    private var signals: URL!

    func testTour() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["LAZYMEMO_DEMO"] == "1", "찍을 때만")
        signals = URL(filePath: env["LAZYMEMO_DEMO_SIGNAL"] ?? "/tmp/lazymemo-demo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: signals, withIntermediateDirectories: true)
        root = URL(filePath: "/tmp/lazymemo-demo-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try seed()

        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        app.launchArguments += ["-tutorialSeen", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        signal("ready")
        pause(1.0)

        // 1. 한 줄 적는다 — 날짜를 앱이 읽어 칩이 선다.
        capture.tap()
        for character in "내일 3시 치과 예약" {
            capture.typeText(String(character))
            pause(0.07)
        }
        pause(0.9)
        app.buttons["leave"].tap()
        pause(1.0)
        dismissKeyboard(app)
        pause(0.6)

        // 2. 그 메모를 열어 다시 볼 시각을 정한다 — 종 → 한 시간 뒤 → 이때 다시 보기.
        row(in: app, startingWith: "치과 예약").tap()
        pause(0.9)
        app.buttons["recall-button"].tap()
        XCTAssertTrue(app.buttons["recall-save"].waitForExistence(timeout: 5))
        pause(1.0)
        app.buttons["한 시간 뒤"].tap()
        pause(0.7)
        app.buttons["recall-save"].tap()
        pause(0.6)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3. 「지금」 — 다시 볼 것이 맨 위에 섰다.
        XCTAssertTrue(app.descendants(matching: .any)["now-band"].waitForExistence(timeout: 5))
        pause(1.8)

        // 4. 이 기기에서 알림 받기 — 켤 때 한 번 묻는다.
        app.buttons["more"].tap()
        pause(0.6)
        app.buttons["reminders-button"].tap()
        let toggle = app.descendants(matching: .any)["recall-enable"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        pause(0.8)
        toggle.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN {'허용', 'Allow'}")).firstMatch
        if allow.waitForExistence(timeout: 5) {
            pause(0.7)
            allow.tap()
        }
        pause(1.2)
        app.buttons["닫기"].firstMatch.tap()
        pause(0.6)

        // 5. 시각이 되었다 — 배너를 누르면 그 메모가 열린다.
        let id = try memoID(containing: "치과 예약")
        signal("push", id)
        // 배너는 `Other` 가 아니라 제 나름의 종류라 `.any` 로 찾는다 — 그리고 대여섯 초면 사라지므로 한 번에.
        let shown = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'NotificationShortLookView' OR label CONTAINS '치과 예약'")
        ).firstMatch
        if shown.waitForExistence(timeout: 10) {
            pause(1.3)
            shown.tap()
            XCTAssertTrue(app.textViews["paper"].waitForExistence(timeout: 5), "배너를 누르면 그 메모가 열려야 한다")
            pause(2.2)
        } else {
            XCTFail("배너가 안 떴다 — 스크립트의 simctl push 가 닿았는지 볼 것")
        }
        signal("done")
    }

    // MARK: 무대

    private func seed() throws {
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        let attachments = root.appending(path: "vault/attachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        let card = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { context in
            UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            UIColor(red: 0.16, green: 0.32, blue: 0.27, alpha: 1).setFill()
            context.fill(CGRect(x: 48, y: 48, width: 200, height: 24))
            context.fill(CGRect(x: 48, y: 96, width: 320, height: 12))
        }
        try XCTUnwrap(card.pngData()).write(to: attachments.appending(path: "01K4ZR0000000000000000AF.png"))
        let today = Date().formatted(.iso8601.year().month().day())
        let memos: [(String, String, String, String, Bool, String?)] = [
            ("01K4ZR0000000000000000AA", "장보기\n우유, 계란, 두부", "", "yellow", false, "집"),
            ("01K4ZR0000000000000000AC", "회의 자료 보내기\n분기 계획 초안까지", "due: \(today)\n", "green", false, "일"),
            ("01K4ZR0000000000000000AD", "읽을 것: 설계 문서", "", "gray", true, "읽을 것"),
            ("01K4ZR0000000000000000AE", "집 — 전구 갈기\n거실 등, E26", "", "pink", false, "집"),
            ("01K4ZR0000000000000000AF", "명함 — 김 디자이너\n![](attachments/01K4ZR0000000000000000AF.png)", "", "blue", false, nil),
        ]
        for (index, memo) in memos.enumerated() {
            let stamp = String(format: "2026-09-%02dT10:00:00+09:00", 10 + index)
            let folder = memo.5.map { "folder: \($0)\n" } ?? ""
            let text = "---\nid: \(memo.0)\ncreated: \(stamp)\nupdated: \(stamp)\n\(memo.2)tags: []\ncolor: \(memo.3)\npinned: \(memo.4)\n\(folder)---\n\(memo.1)\n"
            try text.write(to: notes.appending(path: memo.0 + ".md"), atomically: true, encoding: .utf8)
        }
    }

    /// 방금 적힌 메모의 id — 파일에서 읽는다. 배너의 payload 가 이것을 든다.
    private func memoID(containing text: String) throws -> String {
        let notes = root.appending(path: "vault/notes", directoryHint: .isDirectory)
        let files = try XCTUnwrap(FileManager.default.enumerator(at: notes, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "md" }
        for file in files {
            let body = try String(contentsOf: file, encoding: .utf8)
            guard body.contains(text) else { continue }
            if let line = body.split(separator: "\n").first(where: { $0.hasPrefix("id: ") }) {
                return String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            }
        }
        throw XCTSkip("메모 파일을 못 찾았다")
    }

    /// 스크립트와 나누는 신호 — 파일 하나, 안에는 지금 시각(초).
    private func signal(_ name: String, _ content: String? = nil) {
        let text = content ?? String(Date().timeIntervalSince1970)
        try? text.write(to: signals.appending(path: name), atomically: true, encoding: .utf8)
    }

    private func pause(_ seconds: Double) {
        usleep(UInt32(seconds * 1_000_000))
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func row(in app: XCUIApplication, startingWith title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }
}
