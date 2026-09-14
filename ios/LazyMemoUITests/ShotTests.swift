import XCTest

/// 눈으로 보려고 찍는다 — 맥의 `render-ui.sh` 자리. `./ios/scripts/uitest.sh --shots` 로만 돈다.
/// 결과는 /tmp/shot-{pen,list,editor,recall,datesheet,calendar}.png.
final class ShotTests: XCTestCase {
    func testShots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LAZYMEMO_SHOTS"] == "1", "찍을 때만")
        let root = URL(filePath: "/tmp/lazymemo-shots-\(UUID().uuidString)", directoryHint: .isDirectory)
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        let memos: [(String, String, String, String, Bool, String?)] = [
            ("01K4ZR0000000000000000AA", "장보기\n우유, 계란, 두부", "due: 2026-09-14\n", "yellow", false, nil),
            ("01K4ZR0000000000000000AB", "치과 예약 — 강남역 3번 출구", "at: 2026-09-15T15:00:00+09:00\nplace: 강남역\n", "blue", false, nil),
            ("01K4ZR0000000000000000AC", "회의 자료 보내기", "due: 2026-09-15\n", "green", false, "일"),
            ("01K4ZR0000000000000000AD", "읽을 것: 설계 문서", "", "gray", true, "읽을 것"),
            ("01K4ZR0000000000000000AE", "집 — 전구 갈기\n거실 등, E26", "", "pink", false, "집"),
        ]
        for (index, memo) in memos.enumerated() {
            let stamp = String(format: "2026-09-%02dT10:00:00+09:00", 10 + index)
            let folder = memo.5.map { "folder: \($0)\n" } ?? ""
            let text = "---\nid: \(memo.0)\ncreated: \(stamp)\nupdated: \(stamp)\n\(memo.2)tags: []\ncolor: \(memo.3)\npinned: \(memo.4)\n\(folder)---\n\(memo.1)\n"
            try text.write(to: notes.appending(path: memo.0 + ".md"), atomically: true, encoding: .utf8)
        }
        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        app.launchArguments += ["-tutorialSeen", "YES"]
        // 찍는 말은 한국어다 — 아래의 누르는 자리가 한국어 낱말로 적혀 있다.
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap(); capture.typeText("내일 3시 치과 @강남역")
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-pen.png"))
        app.buttons["clear"].tap()

        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-list.png"))

        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '치과 예약'")).firstMatch.tap()
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-editor.png"))
        app.buttons["recall-button"].tap()
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-recall.png"))
        app.buttons["닫기"].firstMatch.tap()
        sleep(1)
        app.descendants(matching: .any)["tail-date"].firstMatch.tap()
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-datesheet.png"))
        app.buttons["완료"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.tabBars.buttons["달력"].tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '15일'")).firstMatch.tap()
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/shot-calendar.png"))
        try? FileManager.default.removeItem(at: root)
    }
}
