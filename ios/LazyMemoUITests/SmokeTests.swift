import XCTest

/// 손 없이 조작 경로를 따라간다 — 맥의 `scripts/verify-*.sh` 가 하는 일을
/// 폰에서는 XCUITest 가 한다.
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

    func testWrittenMemoBecomesAFileAndShowsUp() throws {
        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        app.launch()

        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10), "빠른 입력 칸이 없다")
        capture.tap()
        capture.typeText("dentist tomorrow at 3pm")

        let leave = app.buttons["leave"]
        XCTAssertEqual(leave.label, "달력에 남기기", "날짜를 읽었으면 단추가 그렇게 말해야 한다")
        leave.tap()

        // 날짜 조각은 덜어내고 나머지가 제목이 된다 — 맥과 같은 규칙(NoteReader).
        XCTAssertTrue(app.staticTexts["dentist"].waitForExistence(timeout: 5), "목록에 안 보인다")

        let notes = root.appending(path: "vault/notes", directoryHint: .isDirectory)
        let files = try markdownFiles(under: notes)
        XCTAssertEqual(files.count, 1, "파일이 정확히 한 장이어야 한다")

        let text = try String(contentsOf: try XCTUnwrap(files.first), encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("---\n"), "frontmatter 가 없다")
        XCTAssertTrue(text.contains("\nat: "), "시각이 파일에 안 적혔다")
        XCTAssertTrue(text.hasSuffix("dentist\n") || text.hasSuffix("dentist"), "본문이 다르다: \(text)")
    }

    private func markdownFiles(under directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return enumerator.compactMap { ($0 as? URL).flatMap { $0.pathExtension == "md" ? $0 : nil } }
    }
}
