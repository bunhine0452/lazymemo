import XCTest

/// 손 없이 조작 경로를 따라간다 — 맥의 `scripts/verify-*.sh` 가 하는 일을
/// 폰에서는 XCUITest 가 한다 (MOBILE_DESIGN §12).
///
/// 앱은 `LAZYMEMO_VAULT` 로 버리는 폴더를 받는다 (`AppPaths.resolveCloud` 에서도
/// 이것이 가장 세다). 시험이 진짜 iCloud 컨테이너를 건드리는 일은 없다.
final class SmokeTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        continueAfterFailure = false
        root = URL(filePath: "/tmp/lazymemo-uitest-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: 펜 — 적으면 파일이 되고 줄이 펜 위에 앉는다

    func testWrittenMemoBecomesAFileAndShowsUp() throws {
        let app = launch()

        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10), "펜이 없다")
        capture.tap()
        capture.typeText("dentist tomorrow at 3pm")

        XCTAssertTrue(app.descendants(matching: .any)["chip-date"].waitForExistence(timeout: 3), "읽은 날짜가 칩으로 보여야 한다")
        let leave = app.buttons["leave"]
        XCTAssertEqual(leave.label, "달력에 남기기", "날짜를 읽었으면 단추가 그렇게 말해야 한다")
        leave.tap()

        XCTAssertTrue(row(in: app, startingWith: "dentist").waitForExistence(timeout: 5), "줄이 안 보인다")
        // 빈 칸의 value 는 안내 문구다 — 적은 글이 남아 있지 않으면 된다.
        XCTAssertFalse((capture.value as? String ?? "").contains("dentist"), "적기 끝에 글 칸이 비어야 한다")

        let files = try markdownFiles(under: root.appending(path: "vault/notes", directoryHint: .isDirectory))
        XCTAssertEqual(files.count, 1)
        let text = try String(contentsOf: try XCTUnwrap(files.first), encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("---\n"))
        XCTAssertTrue(text.contains("\nat: "), "시각이 파일에 안 적혔다")
        XCTAssertTrue(text.hasSuffix("dentist\n") || text.hasSuffix("dentist"), "본문이 다르다: \(text)")
    }

    // MARK: 펜 — 치면 걸러진다, 첫소리로도

    func testTypingFiltersTheStack() throws {
        try seed()
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        XCTAssertTrue(row(in: app, startingWith: "장보기").waitForExistence(timeout: 5))
        XCTAssertTrue(row(in: app, startingWith: "치과 예약").exists)

        capture.tap()
        capture.typeText("ㅊㄱ")

        XCTAssertTrue(row(in: app, startingWith: "치과 예약").waitForExistence(timeout: 5), "첫소리로 찾아야 한다")
        XCTAssertFalse(row(in: app, startingWith: "장보기").exists, "안 맞는 것은 빠져야 한다")
        XCTAssertEqual(app.buttons["leave"].label, "메모 남기기", "찾는 중에도 남기기는 살아 있다")
    }

    // MARK: 지우기 — 되돌리기 띠가 펜 위에 뜬다

    func testSwipeDeleteOffersUndo() throws {
        try seed()
        let app = launch()
        let target = row(in: app, startingWith: "집 — 전구 갈기")
        XCTAssertTrue(target.waitForExistence(timeout: 10))

        target.swipeLeft()
        let delete = app.buttons["지우기"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        let undo = app.buttons["undo"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "되돌리기 띠가 없다")
        XCTAssertFalse(row(in: app, startingWith: "집 — 전구 갈기").exists)
        undo.tap()
        XCTAssertTrue(row(in: app, startingWith: "집 — 전구 갈기").waitForExistence(timeout: 3), "되돌린 줄이 안 돌아왔다")
    }

    // MARK: 편집 — 저장 버튼 없이 파일이 바뀐다

    func testEditingWritesTheFile() throws {
        try seed()
        let app = launch()
        let target = row(in: app, startingWith: "집 — 전구 갈기")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5), "종이가 안 열렸다")
        // 누른 자리에 커서가 선다 — 어디든 적히면 된다.
        paper.tap()
        paper.typeText("(10W)")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let changed = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '(10W)'")).firstMatch
        XCTAssertTrue(changed.waitForExistence(timeout: 5), "고친 글이 줄에 안 보인다")
        let file = root.appending(path: "vault/notes/2026/09/\(Self.ulid(day: 14, tail: "AE")).md")
        let saved = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(saved.contains("(10W)"), "파일이 안 바뀌었다: \(saved)")
    }

    // MARK: 달력 — 그 날에 선다

    func testCalendarShowsTheDay() throws {
        try seed()
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["capture"].waitForExistence(timeout: 10))
        app.tabBars.buttons["달력"].tap()

        // 15일 칸을 누르면 그 날의 둘이 선다.
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '15일'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "15일 칸이 없다")
        cell.tap()
        XCTAssertTrue(app.staticTexts["치과 예약 — 강남역 3번 출구"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["회의 자료 보내기"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["chip-date"].exists, "고른 날이 펜에 물려야 한다")
    }

    // MARK: 도우미

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        app.launch()
        return app
    }

    private func row(in app: XCUIApplication, startingWith title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// 맥 형식 그대로의 파일 몇 장 — 2026-09 기준.
    private func seed() throws {
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        // id 의 시각과 폴더(2026/09)가 맞아야 한다 — 앱은 id 의 시각으로 자리를 정한다.
        let memos: [(String, String, String, String, Bool, String?)] = [
            (Self.ulid(day: 10, tail: "AA"), "장보기\n우유, 계란, 두부", "due: 2026-09-14\n", "yellow", false, nil),
            (Self.ulid(day: 11, tail: "AB"), "치과 예약 — 강남역 3번 출구", "at: 2026-09-15T15:00:00+09:00\nplace: 강남역\n", "blue", false, nil),
            (Self.ulid(day: 12, tail: "AC"), "회의 자료 보내기", "due: 2026-09-15\n", "green", false, "일"),
            (Self.ulid(day: 13, tail: "AD"), "읽을 것: 설계 문서", "", "gray", true, "읽을 것"),
            (Self.ulid(day: 14, tail: "AE"), "집 — 전구 갈기", "", "pink", false, "집"),
        ]
        for (index, memo) in memos.enumerated() {
            let stamp = String(format: "2026-09-%02dT10:00:00+09:00", 10 + index)
            let folder = memo.5.map { "folder: \($0)\n" } ?? ""
            let text = "---\nid: \(memo.0)\ncreated: \(stamp)\nupdated: \(stamp)\n\(memo.2)tags: []\ncolor: \(memo.3)\npinned: \(memo.4)\n\(folder)---\n\(memo.1)\n"
            try text.write(to: notes.appending(path: memo.0 + ".md"), atomically: true, encoding: .utf8)
        }
    }

    /// 2026년 9월 `day` 일 10:00 KST 의 ULID. 앞 열 글자가 시각(Crockford base32).
    private static func ulid(day: Int, tail: String) -> String {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 9; parts.day = day; parts.hour = 10
        parts.timeZone = TimeZone(identifier: "Asia/Seoul")
        let millis = UInt64(Calendar(identifier: .gregorian).date(from: parts)!.timeIntervalSince1970 * 1000)
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        var stamp = ""
        var rest = millis
        for _ in 0..<10 { stamp = String(alphabet[Int(rest % 32)]) + stamp; rest /= 32 }
        return stamp + String(repeating: "0", count: 16 - tail.count) + tail
    }

    private func markdownFiles(under directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { ($0 as? URL).flatMap { $0.pathExtension == "md" ? $0 : nil } }
    }
}
