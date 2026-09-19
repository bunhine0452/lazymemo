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
        XCTAssertTrue(app.staticTexts["이 기기에만 · iCloud 꺼짐"].exists, "저장 자리가 부제에 있어야 한다")
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
        XCTAssertTrue(scrolledRow(in: app, startingWith: "장보기").exists)
        XCTAssertTrue(scrolledRow(in: app, startingWith: "치과 예약").exists)

        capture.tap()
        capture.typeText("ㅊㄱ")

        XCTAssertTrue(row(in: app, startingWith: "치과 예약").waitForExistence(timeout: 5), "첫소리로 찾아야 한다")
        XCTAssertFalse(row(in: app, startingWith: "장보기").exists, "안 맞는 것은 빠져야 한다")
        XCTAssertEqual(app.buttons["leave"].label, "메모 남기기", "찾는 중에도 남기기는 살아 있다")
        XCTAssertEqual(app.staticTexts["scope"].label, "6장 중 1장", "찾기의 범위를 적어야 한다")

        app.buttons["clear"].tap()
        XCTAssertTrue(scrolledRow(in: app, startingWith: "장보기").exists, "⊗ 로 비우면 목록이 돌아온다")
    }

    // MARK: 지우기 — 휴지통에서 돌아온다

    func testDeletedMemoReturnsFromTrash() throws {
        try seed()
        let app = launch()
        let target = scrolledRow(in: app, startingWith: "집 — 전구 갈기")
        XCTAssertTrue(target.exists)

        target.swipeLeft()
        let delete = app.buttons["지우기"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertFalse(row(in: app, startingWith: "집 — 전구 갈기").waitForExistence(timeout: 1))

        app.buttons["trash-button"].tap()
        let restore = app.buttons["restore"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 5), "휴지통에 없다")
        restore.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row(in: app, startingWith: "집 — 전구 갈기").waitForExistence(timeout: 5), "되돌린 줄이 안 돌아왔다")
    }

    // MARK: 미루기 — 일정이 있는 줄은 메모 탭에서도 오른쪽으로 밀면 하루 미뤄진다 (달력 탭과 같은 손짓)

    func testPostponeFromTheListMovesTheDate() throws {
        try seed()
        // 씨앗의 「치과」는 오늘 것이라 「지금」 띠에 오른다 — 목록의 줄로 밀려면 내일 15시의 약속을 하나 더 심는다.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let at = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: tomorrow)!
        let id = Self.ulid(day: 15, tail: "AG")
        let seedText = "---\nid: \(id)\ncreated: 2026-09-15T10:00:00+09:00\nupdated: 2026-09-15T10:00:00+09:00\nat: \(at.formatted(Date.ISO8601FormatStyle(timeZone: .current)))\ntags: []\ncolor: blue\npinned: false\n---\n안과 예약\n"
        let file = root.appending(path: "vault/notes/2026/09/\(id).md")
        try seedText.write(to: file, atomically: true, encoding: .utf8)
        let app = launch()
        let target = scrolledRow(in: app, startingWith: "안과 예약")
        XCTAssertTrue(target.exists)

        target.swipeRight()
        let postpone = app.buttons["미루기"]
        XCTAssertTrue(postpone.waitForExistence(timeout: 3), "일정이 있는 줄을 오른쪽으로 밀면 「미루기」가 있어야 한다")
        postpone.tap()

        // 내일 15시는 모레 15시로 — 시각은 그대로 (`Schedule.postponed`).
        let day = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
            .formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let deadline = Date().addingTimeInterval(5)
        var text = ""
        repeat {
            text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            if text.contains("at: \(day)T15:00") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        XCTAssertTrue(text.contains("at: \(day)T15:00"), "하루 미룬 시각이 파일에 적혀야 한다: \(text)")
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

    // MARK: 자리 카드 — 칸의 자리와 본문의 @낱말이 카드 두 장, 쓸어 넘긴다

    func testTwoPlacesMakeTwoCards() throws {
        try seed()
        let app = launch()
        let target = row(in: app, startingWith: "동선")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let cards = app.descendants(matching: .any).matching(identifier: "place-card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 5), "자리 카드가 없다")
        XCTAssertEqual(cards.count, 2, "칸의 강남역과 본문의 홍대입구, 두 장이어야 한다")
        XCTAssertEqual(cards.element(boundBy: 0).label, "자리 강남역", "칸의 자리가 첫 장이다")
        XCTAssertEqual(cards.element(boundBy: 1).label, "자리 홍대입구")

        let strip = app.descendants(matching: .any).matching(identifier: "place-cards").firstMatch
        strip.swipeLeft()
        XCTAssertTrue(cards.element(boundBy: 1).isHittable, "쓸어 넘기면 둘째 장이 손에 닿는다")
        // 종이 위에 카드가 앉아도 글은 보인다 — 카드가 화면을 먹으면 이것이 잡는다.
        XCTAssertTrue(app.textViews["paper"].isHittable, "종이가 카드에 가렸다")
    }

    // MARK: 편집 — 키보드가 꼬리를 덮는 동안 「완료」가 위에 선다

    func testDoneLowersTheKeyboardInTheEditor() throws {
        try seed()
        let app = launch()
        let target = row(in: app, startingWith: "집 — 전구 갈기")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["done-editing"].exists, "열 때는 키보드도 「완료」도 없다")
        paper.tap()
        let done = app.buttons["done-editing"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "적는 동안 「완료」가 있어야 한다")
        XCTAssertGreaterThan(app.keyboards.count, 0)
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "「완료」가 키보드를 안 내렸다")
        XCTAssertFalse(done.exists)
        XCTAssertTrue(app.buttons["tail-date"].isHittable, "키보드가 내려가면 꼬리가 손에 잡혀야 한다")
    }

    // MARK: 날짜 시트 — 붙어 있는 시각을 말하고, 고른 시각이 제목에 따라온다

    func testDateSheetShowsTheClock() throws {
        try seed()
        let app = launch()
        let target = row(in: app, startingWith: "치과 예약")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let tail = app.buttons["tail-date"]
        XCTAssertTrue(tail.waitForExistence(timeout: 5))
        tail.tap()
        let title = app.navigationBars.staticTexts.matching(NSPredicate(format: "label CONTAINS '15:00'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3), "시트 제목에 시각이 없다")
        app.buttons["09:00"].tap()
        let moved = app.navigationBars.staticTexts.matching(NSPredicate(format: "label CONTAINS '9:00'")).firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 3), "고른 시각이 제목에 안 따라왔다")
    }

    // MARK: 달력 — 그 날에 선다

    func testCalendarShowsTheDay() throws {
        try seed()
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["capture"].waitForExistence(timeout: 10))
        // 켜면 키보드가 올라와 탭바를 덮는다 — 목록을 쓸어 내려 키보드를 내린다 (사람도 그렇게 한다).
        dismissKeyboard(app)
        let calendarTab = app.tabBars.buttons["달력"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 3) && calendarTab.isHittable, "키보드가 내려가야 탭바가 닿는다")
        calendarTab.tap()

        // 오늘 칸을 누르면 그 날의 둘이 선다 (씨앗의 일정은 오늘 기준).
        let day = Calendar.current.component(.day, from: Date())
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(day)일")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "\(day)일 칸이 없다")
        cell.tap()
        XCTAssertTrue(app.staticTexts["치과 예약 — 강남역 3번 출구"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["회의 자료 보내기"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["chip-date"].exists, "고른 날이 펜에 물려야 한다")
    }

    // MARK: 지금 여기 — 누를 때만 묻고, 한 번 재고, 칩으로 물린다

    func testHerePinAttachesAPlace() throws {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["capture"].waitForExistence(timeout: 10))

        // 권한과 자리는 ios/scripts/uitest.sh 가 simctl 로 미리 준다 — 시스템 권한
        // 창을 시험이 기다리지 않게. 실기기의 첫 누름은 그 창을 진짜로 띄운다.
        // 시스템 위치 단추는 식별자를 받지 않아 이름으로 찾는다.
        let here = app.descendants(matching: .any)["here"]
        XCTAssertTrue(here.waitForExistence(timeout: 5), "위치 단추가 없다")
        here.tap()

        let chip = app.descendants(matching: .any)["chip-place"]
        let trouble = app.descendants(matching: .any)["here-trouble"]
        let settled = NSPredicate { _, _ in chip.exists || trouble.exists }
        let expectation = XCTNSPredicateExpectation(predicate: settled, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 20), .completed, "칩도 안내도 안 왔다")
        XCTAssertTrue(chip.exists, "자리가 칩으로 물려야 한다 — 시뮬레이터에 위치가 없으면 「위치를 못 잡았습니다」가 뜬다")
    }

    // MARK: 첫 실행 — 안내가 뜨고, 닫히면 그제야 펜이 올라온다

    func testFirstLaunchShowsTutorialThenThePen() throws {
        let app = launch(tutorialSeen: false)
        XCTAssertTrue(app.buttons["tutorial-next"].waitForExistence(timeout: 10), "첫 실행에 안내가 떠야 한다")
        XCTAssertEqual(app.keyboards.count, 0, "안내 위로 키보드가 오르면 안 된다")

        for _ in 0..<3 { app.buttons["tutorial-next"].tap() }
        let done = app.buttons["tutorial-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "마지막 장은 「시작하기」여야 한다")
        done.tap()

        XCTAssertFalse(app.buttons["tutorial-done"].waitForExistence(timeout: 1), "닫혀야 한다")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "안내가 닫히면 펜이 올라와야 한다")

        // More 메뉴에서 다시 볼 수 있다.
        dismissKeyboard(app)
        app.buttons["more"].tap()
        app.buttons["tutorial-button"].tap()
        XCTAssertTrue(app.buttons["tutorial-skip"].waitForExistence(timeout: 3), "「사용법」으로 다시 열려야 한다")
        app.buttons["tutorial-skip"].tap()
    }

    // MARK: 칩 — 끄면 빈 테두리로 남고, 다시 누르면 켜진다

    func testDateChipStaysWhenTurnedOff() throws {
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        capture.typeText("dentist tomorrow at 3pm")

        let chip = app.descendants(matching: .any)["chip-date"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        chip.tap()
        XCTAssertTrue(chip.exists, "끈 칩은 빈 테두리로 남아야 한다 — 사라지면 다시 켤 길이 없다")
        XCTAssertEqual(chip.value as? String, "꺼짐")
        XCTAssertEqual(app.buttons["leave"].label, "메모 남기기", "날짜를 안 읽으면 단추도 그렇게 말한다")

        chip.tap()
        XCTAssertEqual(chip.value as? String, "켜짐")
        XCTAssertEqual(app.buttons["leave"].label, "달력에 남기기")
    }

    // MARK: 도우미

    /// 첫 실행 안내는 따로 시험한다 — 나머지는 「본 것」으로 켠다.
    // MARK: 다시 보기 — 「지금」 띠가 서고, 종을 누르면 시각이 파일에 적힌다

    func testRevisitWritesSurfaceAndNowBandShowsPinned() throws {
        try seed()
        let app = launch()

        // 고정한 메모는 날짜와 상관없이 「지금」에 오른다 — 씨앗의 「읽을 것: 설계 문서」.
        let band = app.descendants(matching: .any)["now-band"]
        XCTAssertTrue(band.waitForExistence(timeout: 10), "「지금」 띠가 없다")
        let cards = app.descendants(matching: .any).matching(identifier: "now-card")
        let card = cards.matching(NSPredicate(format: "label CONTAINS %@", "읽을 것")).firstMatch
        XCTAssertTrue(card.exists, "고정한 메모가 카드로 서야 한다")
        XCTAssertTrue(card.label.hasPrefix("고정"), "이유가 먼저 읽혀야 한다: \(card.label)")
        XCTAssertLessThanOrEqual(cards.count, 3, "셋을 넘으면 띠가 아니라 목록이다")

        // 찾는 중에는 띠가 없다 — 범위를 흐리지 않는다.
        let capture = app.descendants(matching: .any)["capture"]
        capture.tap()
        capture.typeText("전구")
        XCTAssertTrue(row(in: app, startingWith: "집 — 전구 갈기").waitForExistence(timeout: 5))
        XCTAssertFalse(band.exists, "찾는 중에는 「지금」이 사라져야 한다")
        app.buttons["clear"].tap()
        XCTAssertTrue(band.waitForExistence(timeout: 3), "찾기를 비우면 띠가 돌아온다")
        dismissKeyboard(app)

        // 종을 누르면 시트, 기본 시각은 한 시간 뒤라 바로 저장할 수 있다.
        row(in: app, startingWith: "집 — 전구 갈기").tap()
        let bell = app.buttons["recall-button"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), "편집 화면에 다시 보기 종이 없다")
        bell.tap()
        let save = app.buttons["recall-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "다시 보기 시트가 안 떴다")
        XCTAssertTrue(app.descendants(matching: .any)["recall-enable"].exists, "기기 알림 켜기가 같은 시트에 있어야 한다")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "저장하면 시트가 닫혀야 한다")

        // 파일에 surface 가 적혔고, 종은 「정해 둠」으로 바뀐다.
        let files = try markdownFiles(under: root.appending(path: "vault/notes", directoryHint: .isDirectory))
        let file = try XCTUnwrap(files.first { (try? String(contentsOf: $0, encoding: .utf8))?.contains("전구 갈기") == true })
        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(text.contains("\nsurface: "), "다시 볼 시각이 파일에 안 적혔다: \(text)")
        XCTAssertTrue(bell.label.contains("다시 보기"), bell.label)
        bell.tap()
        XCTAssertTrue(app.descendants(matching: .any)["recall-current"].waitForExistence(timeout: 5), "정해 둔 시각이 시트에 보여야 한다")
        let clear = app.buttons["recall-clear"]
        XCTAssertTrue(clear.exists, "해제 단추가 있어야 한다")
        clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 5))
        let after = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(after.contains("\nsurface: "), "해제하면 파일에서 빠져야 한다: \(after)")
    }

    // MARK: 「지금」 — 띠에 오른 것은 목록에 없고, 「봤어요」로 내려놓으면 「나머지」로 돌아간다

    func testSeenPutsTheCardDownIntoTheRest() throws {
        try seed()
        let app = launch()
        let cards = app.descendants(matching: .any).matching(identifier: "now-card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "「지금」 띠가 없다")
        let pinned = cards.matching(NSPredicate(format: "label CONTAINS %@", "읽을 것")).firstMatch
        XCTAssertTrue(pinned.exists)
        let rest = app.staticTexts["rest"]
        XCTAssertTrue(rest.exists, "띠 아래는 「나머지」다")
        // 씨앗 여섯 장 중 띠에 오른 만큼 빠진다 — 오늘 일정이 몇인지는 오늘이 정한다.
        let risen = cards.count
        XCTAssertEqual(rest.label, "나머지 \(6 - risen)장", "띠에 오른 것은 아래에서 빠져야 한다: \(rest.label)")
        // 목록의 줄로는 없다 — 카드로만 있다 (줄의 말은 「…, 고정됨」으로 끝난다).
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "읽을 것", "고정됨")).count, 0)

        // 고정 카드의 「봤어요」 — 카드 안의 단추라 카드와 같은 자리에서 찾는다.
        let inside = pinned.buttons["now-seen"]
        let seen = inside.exists ? inside : app.buttons.matching(identifier: "now-seen").element(boundBy: risen - 1)
        XCTAssertTrue(seen.exists, "카드 위에 「봤어요」가 보여야 한다")
        seen.tap()
        XCTAssertTrue(pinned.waitForNonExistence(timeout: 3), "내려놓은 카드는 띠에서 빠진다")
        XCTAssertTrue(app.staticTexts["나머지 \(7 - risen)장"].waitForExistence(timeout: 3), "내려놓은 것은 목록으로 돌아간다")
        XCTAssertTrue(scrolledRow(in: app, startingWith: "읽을 것").exists, "목록의 줄로 돌아와야 한다")
    }

    // MARK: 사진 — 맥이 붙인 사진이 폰의 종이 머리에 선다, 줄에는 경로가 아니라 「사진 1장」

    func testPhotoFromMacShowsOnThePaper() throws {
        try seed()
        try seedPhoto()
        let app = launch()
        let target = row(in: app, startingWith: "명함 사진")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertFalse(target.label.contains("attachments/"), "줄에 파일 경로가 보이면 안 된다: \(target.label)")
        XCTAssertTrue(target.label.contains("사진 1장"), "붙인 사진은 수로 적는다: \(target.label)")
        target.tap()

        let photo = app.descendants(matching: .any)["photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "사진이 종이 머리에 서야 한다")
        XCTAssertTrue(app.textViews["paper"].isHittable, "종이가 사진에 가렸다")
        photo.tap()
        let viewer = app.descendants(matching: .any)["photo-viewer"].firstMatch
        XCTAssertTrue(viewer.waitForExistence(timeout: 5), "누르면 전체 화면으로 펼쳐야 한다")
        app.buttons["photo-close"].tap()
        XCTAssertTrue(viewer.waitForNonExistence(timeout: 5))
    }

    /// 맥이 붙인 그대로 — `attachments/<ulid>.png` 와 본문의 `![](…)`.
    private func seedPhoto() throws {
        let attachments = root.appending(path: "vault/attachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 200)).image { context in
            UIColor(red: 0.16, green: 0.32, blue: 0.27, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 200))
            UIColor.white.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 240, height: 120))
        }
        try XCTUnwrap(image.pngData()).write(to: attachments.appending(path: "01K4ZR0000000000000000B1.png"))
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        // 가장 최근 것이라 목록 위쪽에 선다 — 스크롤 없이 닿아야 한다.
        let id = Self.ulid(day: 14, tail: "B1")
        let text = "---\nid: \(id)\ncreated: 2026-09-14T12:00:00+09:00\nupdated: 2026-09-14T12:00:00+09:00\ntags: []\ncolor: yellow\npinned: false\n---\n명함 사진\n![](attachments/01K4ZR0000000000000000B1.png)\n"
        try text.write(to: notes.appending(path: id + ".md"), atomically: true, encoding: .utf8)
    }

    // MARK: 기계가 적은 줄 — 사진 참조와 가는 길 절은 글 칸에서 안 보이고, 커서는 그 안에 못 들어간다

    /// 2026-09-17 사용자의 화면: 카드 아래에 `## 가는 길 …` 과 `![](attachments/…)` 가 날것으로 보였다.
    /// 글자는 파일에 그대로 있어야 하고(카드가 그것을 읽는다), 글 끝을 눌러 이어 적으면 절 **앞**에 적혀야 한다.
    func testMachineLinesAreHiddenAndTypingLandsBeforeTheRoute() throws {
        try seed()
        try seedPhoto()
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        let id = Self.ulid(day: 14, tail: "C1")
        let lunch = Calendar.current.date(bySettingHour: 13, minute: 56, second: 0, of: Calendar.current.startOfDay(for: Date()))!
        let at = lunch.formatted(Date.ISO8601FormatStyle(timeZone: .current))
        let route = "## 가는 길\n삼전동 66-4 → 마루가메 우동 잠실롯데월드몰 · 22분 · 13:34 출발 · 13:56 도착 · 1,500원\n- 걷기 3분\n- 버스 3315 (지선) 삼전동쌍용하이츠빌라 → 잠실역1번.11번출구 · 12분 · 7정류장\n- 걷기 6분"
        // 첫 줄은 맥에서 붙인 지도 주소 그대로 — 폰에서는 「map.naver.com/2040338336 점심 약속」으로 보여야 한다.
        let body = "[map.naver.com/2040338336](https://map.naver.com/p/entry/place/2040338336?lng=127.1025624&lat=37.5125701&placePath=%2Fhome) 점심 약속\n![](attachments/01K4ZR0000000000000000B1.png)\n\n" + route
        let file = notes.appending(path: id + ".md")
        try ("---\nid: \(id)\ncreated: 2026-09-14T12:30:00+09:00\nupdated: 2026-09-14T12:30:00+09:00\nat: \(at)\ntags: []\ncolor: yellow\npinned: false\n---\n" + body + "\n")
            .write(to: file, atomically: true, encoding: .utf8)

        let app = launch()
        let target = row(in: app, startingWith: "map.naver.com/2040338336 점심 약속")
        XCTAssertTrue(target.waitForExistence(timeout: 10), "줄의 제목은 링크 이름만 — 주소가 보이면 안 된다")
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["route-card"].waitForExistence(timeout: 5), "길 카드가 서야 한다")
        XCTAssertTrue(app.descendants(matching: .any)["photo"].firstMatch.waitForExistence(timeout: 10), "사진 카드가 서야 한다")
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-machine-lines.png"))

        // 글 아래 빈 자리를 누르면 커서는 글 끝 = 절 안이다 — 절 앞으로 나와야 한다.
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        paper.typeText("덧붙임")
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-machine-lines-typing.png"))
        app.buttons["done-editing"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let saved = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(saved.contains("![](attachments/01K4ZR0000000000000000B1.png)\n덧붙임\n## 가는 길\n삼전동 66-4 →"),
                      "친 글자는 절 앞에, 참조와 절은 그대로여야 한다: \(saved)")
        XCTAssertTrue(saved.hasSuffix("- 걷기 6분\n"), "절의 끝이 그대로여야 한다: \(saved)")
    }

    /// 참조가 감춰졌으니 사진을 떼는 길은 카드뿐이다 — 길게 누르면 「사진 떼기」.
    func testRemovingAPhotoFromItsCard() throws {
        try seed()
        try seedPhoto()
        let app = launch()
        let target = row(in: app, startingWith: "명함 사진")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let photo = app.descendants(matching: .any)["photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.press(forDuration: 1.2)
        let remove = app.buttons["사진 떼기"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3), "길게 누르면 「사진 떼기」가 있어야 한다")
        remove.tap()
        XCTAssertTrue(photo.waitForNonExistence(timeout: 5), "뗀 사진은 카드에서 사라진다")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let file = root.appending(path: "vault/notes/2026/09/\(Self.ulid(day: 14, tail: "B1")).md")
        let saved = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(saved.contains("attachments/"), "참조가 빠져야 한다: \(saved)")
        XCTAssertTrue(saved.hasSuffix("---\n명함 사진\n"), "글은 그대로: \(saved)")
    }

    /// 2026-09-18 사용자(맥 화면): 「사진 넣으면 텍스트 안 보이게 하라 했지?」 — 폰도 ⌫ 가 `)` 를 떼면 참조가
    /// 날것으로 드러나는 길이 있었다. 파일은 끝 줄바꿈 없이 읽히므로 글 끝의 커서는 참조 바로 뒤 — ⌫ 한 번에
    /// 사진이 통째로 빠지고, 그 뒤 친 글자는 그 줄에 보인다.
    func testBackspaceRemovesAPhotoWhole() throws {
        try seed()
        try seedPhoto()
        let app = launch()
        let target = row(in: app, startingWith: "명함 사진")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        let photo = app.descendants(matching: .any)["photo"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "사진 카드가 서야 한다")

        // 글 아래 빈 자리를 누르면 커서는 글 끝 — 감춘 참조 줄의 뒤다.
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        paper.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertTrue(photo.waitForNonExistence(timeout: 5), "⌫ 한 번에 사진이 통째로 빠진다")
        paper.typeText("덧")
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-photo-backspace.png"))
        app.buttons["done-editing"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let file = root.appending(path: "vault/notes/2026/09/\(Self.ulid(day: 14, tail: "B1")).md")
        let saved = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(saved.contains("attachments/"), "참조가 통째로 빠져야 한다 — 깨진 조각이 남으면 안 된다: \(saved)")
        XCTAssertTrue(saved.hasSuffix("---\n명함 사진\n덧\n"), "글은 그대로, 친 글자는 그 줄에: \(saved)")
    }

    // MARK: 알림 설정 — More 메뉴에서 닿고, 켜기 전에 잠금 화면 표시를 읽는다

    func testRemindersSheetOpensFromMore() throws {
        try seed()
        let app = launch()
        XCTAssertTrue(app.buttons["more"].waitForExistence(timeout: 10))
        app.buttons["more"].tap()
        let item = app.buttons["reminders-button"]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "More 에 「알림」이 없다")
        item.tap()
        let toggle = app.descendants(matching: .any)["recall-enable"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "알림 시트가 안 떴다")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "잠금 화면")).firstMatch.exists,
                      "켜기 전에 잠금 화면에 제목이 보인다고 적어야 한다")
        XCTAssertEqual(toggle.value as? String, "0", "첫 실행에는 꺼져 있어야 한다")
    }

    // MARK: 가는 길 — 지도 링크가 든 약속을 남기면 펜이 「어디서 출발하시나요?」를 세운다

    func testAppointmentWithMapLinkAsksWhereToLeaveFrom() throws {
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        capture.typeText("https://naver.me/GFB1MHiW 다음주 금요일 오후 6시반에 밥약속")
        let leave = app.buttons["leave"]
        XCTAssertEqual(leave.label, "달력에 남기기")
        leave.tap()

        let question = app.descendants(matching: .any)["route-question"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "약속을 남기면 출발지를 물어야 한다")
        XCTAssertTrue(app.staticTexts["어디서 출발하시나요?"].exists)
        XCTAssertEqual(leave.label, "답하기", "답을 기다리는 동안 단추는 「답하기」")
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-route-question.png"))

        // 「됐어」— 조용히 물러난다. 메모는 이미 파일이다.
        app.buttons["됐어"].tap()
        XCTAssertFalse(question.waitForExistence(timeout: 1), "됐어 뒤에는 질문이 없어야 한다")
        XCTAssertTrue(row(in: app, startingWith: "https://naver.me").waitForExistence(timeout: 5), "줄이 안 보인다")
        let files = try markdownFiles(under: root.appending(path: "vault/notes", directoryHint: .isDirectory))
        let text = try String(contentsOf: try XCTUnwrap(files.first), encoding: .utf8)
        XCTAssertTrue(text.contains("\nat: "), "약속 시각이 파일에 없다: \(text)")
        XCTAssertFalse(text.contains("## 가는 길"), "됐어 뒤에 길이 적히면 안 된다")
    }

    // MARK: 공유 시트가 남긴 질문 — 앱을 열면 펜이 「어디서 출발하시나요?」를 세운다

    func testShareLeftQuestionIsAskedOnLaunch() throws {
        try seed()
        // 공유 시트가 떨군 약속 메모(자리 있음, 앞으로 올 시각)와 앱 그룹의 표.
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        let id = Self.ulid(day: 16, tail: "RA")
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx"
        let at = stamp.string(from: Date().addingTimeInterval(3 * 3600))
        let text = "---\nid: \(id)\ncreated: 2026-09-16T10:00:00+09:00\nupdated: 2026-09-16T10:00:00+09:00\nat: \(at)\nplace: 광주종합버스터미널(유.스퀘어)\ntags: []\ncolor: yellow\npinned: false\n---\n광주종합버스터미널(유.스퀘어)\n전남광주 서구 무진대로 904\nhttps://naver.me/xqbpqrZD\n"
        try text.write(to: notes.appending(path: id + ".md"), atomically: true, encoding: .utf8)
        let group = root.appending(path: "group", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try "[\"\(id)\"]".write(to: group.appending(path: "route-ask.json"), atomically: true, encoding: .utf8)

        let app = launch(group: group)
        let question = app.descendants(matching: .any)["route-question"]
        if !question.waitForExistence(timeout: 10) {
            try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-route-ask-fail.png"))
            XCTFail("앱을 열면 펜이 출발지를 물어야 한다")
        }
        XCTAssertTrue(app.staticTexts["어디서 출발하시나요?"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "광주종합버스터미널")).firstMatch.exists, "어느 약속인지 한 줄이 있어야 한다")
        XCTAssertFalse(FileManager.default.fileExists(atPath: group.appending(path: "route-ask.json").path(percentEncoded: false)), "거둔 표는 비워야 한다")
    }

    /// 진짜 접속 — 링크를 풀고 지도에 묻고 택시 길을 잰다. `TEST_RUNNER_LAZYMEMO_LIVE_ROUTES=1` 일 때만.
    func testAnsweringTheOriginWritesARouteCard() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LAZYMEMO_LIVE_ROUTES"] == "1", "접속하는 시험 — LAZYMEMO_LIVE_ROUTES=1 로 켠다")
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        capture.typeText("https://naver.me/GFB1MHiW 다음주 금요일 오후 6시반에 밥약속")
        app.buttons["leave"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["route-question"].waitForExistence(timeout: 5))

        capture.typeText("석촌고분역")
        app.buttons["leave"].tap()
        // 네이버 지도 웹이 키 없이 버스·지하철을 준다 — 「버스」 선택지가 서면 길을 잰 것이다.
        let bus = app.buttons["버스"]
        XCTAssertTrue(bus.waitForExistence(timeout: 30), "길을 찾지 못했다: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        bus.tap()

        let notice = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "가는 길을 적었어요")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "적었다는 한 줄이 없다")

        // 파일에 절이, 종이에 카드가.
        let files = try markdownFiles(under: root.appending(path: "vault/notes", directoryHint: .isDirectory))
        let text = try String(contentsOf: try XCTUnwrap(files.first), encoding: .utf8)
        XCTAssertTrue(text.contains("## 가는 길\n석촌고분역 → 투파인드피터 잠실점 ·"), text)
        XCTAssertTrue(text.contains("\n- 버스 ") && text.contains(" 승차"), "버스 번호와 승차 시각이 적혀야 한다: \(text)")
        XCTAssertTrue(text.contains("\nsurface: "), "출발 알림이 걸려야 한다: \(text)")
        dismissKeyboard(app)
        scrolledRow(in: app, startingWith: "https://naver.me").tap()
        XCTAssertTrue(app.descendants(matching: .any)["route-card"].waitForExistence(timeout: 5), "카드가 안 선다")
        try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-route-card.png"))
    }

    // MARK: 종이 — 목록 줄의 ⏎ 는 머리를 잇고, 체크상자는 눌러 뒤집는다

    /// `- [ ] 우유` 한 줄짜리 메모. 목록 시험 둘이 같은 씨앗을 쓴다.
    private static let checklistID = ulid(day: 15, tail: "AG")

    private func seedChecklist() throws {
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        let text = "---\nid: \(Self.checklistID)\ncreated: 2026-09-15T10:00:00+09:00\nupdated: 2026-09-15T10:00:00+09:00\ntags: []\ncolor: yellow\npinned: false\n---\n- [ ] 우유\n"
        try text.write(to: notes.appending(path: Self.checklistID + ".md"), atomically: true, encoding: .utf8)
    }

    private func checklistFile() throws -> String {
        try String(contentsOf: root.appending(path: "vault/notes/2026/09/\(Self.checklistID).md"), encoding: .utf8)
    }

    /// 파일이 `expected` 를 담을 때까지 기다린다 — 자동 저장은 600ms 뒤다.
    private func waitForFile(containing expected: String, timeout: TimeInterval = 5) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var saved = try checklistFile()
        while !saved.contains(expected), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            saved = try checklistFile()
        }
        return saved
    }

    func testReturnContinuesTheChecklist() throws {
        try seedChecklist()
        let app = launch()
        let target = row(in: app, startingWith: "우유")
        XCTAssertTrue(target.waitForExistence(timeout: 10), "줄이 안 보인다")
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5), "종이가 안 열렸다")
        // 첫 줄의 오른쪽 빈 자리 — 커서가 줄 끝에 선다 (위 여백 24 + 글자 절반).
        paper.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: paper.frame.width - 24, dy: 34)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "키보드가 안 올라왔다")
        paper.typeText("\n계란")

        let saved = try waitForFile(containing: "계란")
        XCTAssertTrue(saved.contains("- [ ] 우유\n- [ ] 계란"), "머리가 이어지지 않았다: \(saved)")
    }

    func testTappingACheckboxTogglesIt() throws {
        try seedChecklist()
        let app = launch()
        let target = row(in: app, startingWith: "우유")
        XCTAssertTrue(target.waitForExistence(timeout: 10), "줄이 안 보인다")
        target.tap()

        let paper = app.textViews["paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5), "종이가 안 열렸다")
        // 키보드는 올라오지 않은 채(열 때 올리지 않는다) 첫 줄의 머리 `- [ ] ` 를 누른다 —
        // 왼쪽 여백 16 + 글 여백 5 에서 서너 글자 안.
        paper.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 38, dy: 34)).tap()

        let saved = try waitForFile(containing: "- [x] 우유")
        XCTAssertTrue(saved.contains("- [x] 우유"), "상자가 뒤집히지 않았다: \(saved)")
        XCTAssertEqual(app.keyboards.count, 0, "누르기가 편집을 시작하면 안 된다")
        // 한 번 더 누르면 도로 빈 상자.
        paper.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 38, dy: 34)).tap()
        let back = try waitForFile(containing: "- [ ] 우유")
        XCTAssertTrue(back.contains("- [ ] 우유"), "도로 빈 상자가 되지 않았다: \(back)")
    }

    private func launch(tutorialSeen: Bool = true, group: URL? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LAZYMEMO_VAULT"] = root.path(percentEncoded: false)
        if let group { app.launchEnvironment["LAZYMEMO_GROUP"] = group.path(percentEncoded: false) }
        app.launchArguments += ["-tutorialSeen", tutorialSeen ? "YES" : "NO"]
        // 기기별 기억은 시뮬레이터에 남는다 — 소개 영상(DemoTests)이 알림을 켜 두고 가도, 앞 시험이
        // 「봤어요」로 카드를 내려놓았어도 첫 실행으로 시작한다 (인자 도메인이 저장된 값을 가린다).
        app.launchArguments += ["-recall.notifications.enabled", "NO", "-now-seen", "{}"]
        // 시험은 한국어 낱말을 읽는다 — 시뮬레이터의 말과 상관없이 같은 화면을 보게 고정한다.
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }

    /// 켜면 키보드가 올라와 탭바를 덮는다. 목록을 쓸어 내리면 내려간다 — 사람도 그렇게 한다.
    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        // 목록 위에서 손가락을 천천히 끌어내린다 (빠른 플릭은 시뮬레이터가 스크롤로 안 본다).
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        if app.keyboards.count > 0 {
            try? app.screenshot().pngRepresentation.write(to: URL(filePath: "/tmp/lazymemo-kb.png"))
        }
    }

    private func row(in app: XCUIApplication, startingWith title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// 화면 밖에 있으면 목록을 밀어 올려 찾는다 — 「지금」 띠가 목록의 머리를 차지하므로
    /// 아래쪽 줄은 첫 화면에 없을 수 있다.
    private func scrolledRow(in app: XCUIApplication, startingWith title: String) -> XCUIElement {
        // 앱이 다 뜬 뒤에 센다 — 펜이 곧 「목록이 그려졌다」는 신호다.
        _ = app.descendants(matching: .any)["capture"].waitForExistence(timeout: 10)
        let target = row(in: app, startingWith: title)
        var swipes = 0
        while !target.waitForExistence(timeout: 2), swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        // 펜 바에 반쯤 가린 줄은 손짓이 펜에 닿는다 — 펜 위로 올라올 때까지 민다.
        let pen = app.descendants(matching: .any)["capture"]
        if target.exists, pen.exists, target.frame.maxY > pen.frame.minY - 8 {
            app.swipeUp()
            _ = target.waitForExistence(timeout: 2)
        }
        return target
    }

    /// 맥 형식 그대로의 파일 몇 장 — id·created 는 2026-09 에 박혀 있고, **일정은 오늘 기준**이다.
    ///
    /// 처음엔 일정도 9월 14·15일에 박혀 있었다 — 이틀 뒤 `Tidy`(지난 일정은 다음 날이 끝나면 물러난다)가
    /// 셋을 목록에서 걷어 가서 「나머지 5장」이 「2장」이 됐다. 씨앗은 시험을 쓴 날의 모습(어제 지난 것 하나,
    /// 오늘 것 둘)을 **날마다 다시 만든다.**
    private func seed() throws {
        let notes = root.appending(path: "vault/notes/2026/09", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dentist = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!
        let dayOnly = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
        let clock = Date.ISO8601FormatStyle(timeZone: .current)
        // id 의 시각과 폴더(2026/09)가 맞아야 한다 — 앱은 id 의 시각으로 자리를 정한다.
        let memos: [(String, String, String, String, Bool, String?)] = [
            (Self.ulid(day: 10, tail: "AA"), "장보기\n우유, 계란, 두부", "due: \(yesterday.formatted(dayOnly))\n", "yellow", false, nil),
            (Self.ulid(day: 11, tail: "AB"), "치과 예약 — 강남역 3번 출구", "at: \(dentist.formatted(clock))\nplace: 강남역\n", "blue", false, nil),
            (Self.ulid(day: 12, tail: "AC"), "회의 자료 보내기", "due: \(today.formatted(dayOnly))\n", "green", false, "일"),
            (Self.ulid(day: 13, tail: "AD"), "읽을 것: 설계 문서", "", "gray", true, "읽을 것"),
            (Self.ulid(day: 14, tail: "AE"), "집 — 전구 갈기", "", "pink", false, "집"),
            (Self.ulid(day: 9, tail: "AF"), "동선 — 먼저 보고 @홍대입구 로 이동", "place: 강남역\n", "purple", false, nil),
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
