import CoreGraphics
import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 「서랍」 — **어느 자리에도 없는 종이가 생기지 않는가.**
///
/// 이 화면에서 가장 비싼 고장은 생김새가 아니라 **종이가 사라지는 것**이다.
/// 바탕화면에서 빠졌는데 서랍에도 안 들어가면, 사람이 보는 것은 "메모가
/// 없어졌다" 하나뿐이고 그것은 화면을 봐서는 "원래 없었나" 와 구별되지 않는다.
/// 그래서 무엇이 서랍에 있는지를 뷰 밖의 한 문장으로 두고 여기서 못 박는다.
@Suite("서랍에 무엇이 들어 있는가")
struct DrawerContentsTests {

    private func paper(
        _ title: String = "종이",
        due: CalendarDate? = nil,
        tidied: Date? = nil,
        deleted: Date? = nil
    ) -> Memo {
        Memo(due: due, body: title, deleted: deleted, tidied: tidied)
    }

    @Test("바탕화면에 나와 있는 종이는 서랍에 없다")
    func paperOnTheDeskIsNotInTheDrawer() {
        #expect(!DrawerContents.holds(paper(), putAway: false))
    }

    @Test("치운 종이가 서랍으로 간다 — ×를 누르는 것이 「넣기」다")
    func closingAPaperFilesIt() {
        #expect(DrawerContents.holds(paper(), putAway: true))
    }

    /// 스스로 물러난 종이(`Tidy`)에 **몸을 주는 것**이 이 화면의 절반이다.
    /// 메뉴의 「치워 둔 N장」은 숫자였을 뿐이라, 사람은 그것을 «없어졌다» 로 읽었다.
    @Test("스스로 물러난 것도 서랍에 있다 — 치워 둔 N장이 여기 있다")
    func tidiedPapersLandInTheDrawer() {
        #expect(DrawerContents.holds(paper(tidied: Date()), putAway: false))
    }

    /// 날짜가 붙은 것은 달력이 맡는다 (§7.2). 두 자리에 같은 메모를 두면
    /// 사람이 매번 어느 쪽이 진짜인지 판단해야 한다.
    @Test("날짜가 붙은 것은 달력이 맡는다 — 치웠어도 서랍에 없다")
    func scheduledMemosBelongToTheCalendar() {
        let dated = paper(due: CalendarDate(year: 2026, month: 9, day: 1))
        #expect(!DrawerContents.holds(dated, putAway: true))

        var tidiedAndDated = dated
        tidiedAndDated.tidied = Date()
        #expect(!DrawerContents.holds(tidiedAndDated, putAway: true))
    }

    @Test("지운 것은 휴지통이 맡는다 (D6)")
    func deletedMemosAreNeverInTheDrawer() {
        #expect(!DrawerContents.holds(paper(tidied: Date(), deleted: Date()), putAway: true))
    }

    @Test("골라 내면 차례는 그대로다 — 같은 메모를 두 곳에서 다르게 늘어놓지 않는다")
    func filteringKeepsTheOrder() {
        let first = paper("하나")
        let second = paper("둘")
        let onDesk = paper("셋")
        let filed = DrawerContents.filter([first, second, onDesk]) { $0.id != onDesk.id }

        #expect(filed.map(\.id) == [first.id, second.id])
    }

    @Test("서랍은 몇 장인지 말한다 — 숫자만 있으면 그건 배지다")
    func titleSaysHowManyPapers() {
        #expect(DrawerContents.title(count: 0) == "서랍")
        #expect(DrawerContents.title(count: 3) == "서랍 · 3장")
    }

    /// 무더기에는 여덟 장까지만 놓인다 (`DrawerGeometry.visible`). 그 위를
    /// **조용히 자르면 사람은 그것을 「전부다」로 읽고**, 이 화면에서 가장 비싼
    /// 고장이 바로 «종이가 어디에도 없는 것» 이다. 판형은 `scrolls` 로 넘침을
    /// 이미 셈해 놓고도 화면에서는 한마디도 하지 않고 있었다.
    @Test("여덟 장을 넘으면 몇 장이 가려졌는지 말한다 — 조용히 자르지 않는다")
    func overflowSaysHowManyAreHidden() {
        #expect(DrawerContents.overflow(count: 8, shown: 8) == nil)
        #expect(DrawerContents.overflow(count: 3, shown: 8) == nil)
        #expect(DrawerContents.overflow(count: 11, shown: 8) == "그리고 3장 더")
    }
}

/// 「서랍」의 판형 — **그림 한 장으로는 확인되지 않는 것들.**
///
/// 서랍은 창 하나인데 크기가 셋이다(닫힘·펼침·한 장 되돌림). 그 사이를 창
/// 프레임이 오가므로, 숫자가 어긋나면 **펼치는 동작이 덜컥거리거나 되돌린
/// 종이가 창 밖으로 잘려 나간다.** 화면 오른쪽 끝에서 열었을 때만 드러나는
/// 종류라 렌더에는 흔적이 남지 않는다.
@Suite("서랍의 판형")
struct DrawerGeometryTests {

    @Test("한 장뿐이어도 창은 종이 한 장만큼은 된다")
    func alwaysHasRoomForOnePaper() {
        for count in 0...12 {
            let plan = DrawerGeometry(count: count)
            #expect(plan.inner.width >= DrawerGeometry.paperRoom.width - 0.5)
            #expect(plan.inner.height >= DrawerGeometry.paperRoom.height - 0.5)
        }
    }

    @Test("여덟 장까지 겹쳐 놓고, 넘치면 넘친다고 말한다")
    func stackIsCappedAndReportsOverflow() {
        let few = DrawerGeometry(count: 4)
        #expect(few.stacked == 4)
        #expect(!few.scrolls)

        let many = DrawerGeometry(count: 40)
        #expect(many.stacked == DrawerGeometry.visible)
        // **조용히 자르지 않는다** — 몇 장이 안 보이는지 사람에게 말해야 한다.
        #expect(many.scrolls)
    }

    /// 겹쳐 쌓는 것의 값이 여기 있다 — **첫 줄이 동시에 다 읽힌다.**
    ///
    /// 격자였을 때는 여덟 장이 색으로만 갈려서 하나씩 눌러 봐야 했다. 띠만큼씩
    /// 어긋나 있으면 한눈에 훑힌다.
    @Test("한 장씩 띠만큼 어긋나 쌓인다")
    func sheetsAreOffsetByOneBand() {
        let plan = DrawerGeometry(count: 5)
        #expect(plan.offset(of: 0) == 0)
        #expect(plan.offset(of: 1) == DrawerGeometry.band)
        #expect(plan.offset(of: 4) == DrawerGeometry.band * 4)
        // 띠는 제목 한 줄이 읽히는 만큼이어야 한다.
        #expect(DrawerGeometry.band >= 24)
    }

    @Test("맨 아래 한 장은 통째로 보인다 — 무더기의 바닥이 잘리면 안 된다")
    func theBottomSheetIsWhole() {
        for count in [1, 3, 8, 40] {
            let plan = DrawerGeometry(count: count)
            let pile = plan.offset(of: plan.stacked - 1) + DrawerGeometry.sheet.height
            #expect(plan.inner.height >= pile)
        }
    }

    @Test("장수가 늘면 창도 자란다 — 다만 한없이는 아니다")
    func windowGrowsWithTheCount() {
        let small = DrawerGeometry(count: 2)
        let medium = DrawerGeometry(count: 8)
        let huge = DrawerGeometry(count: 200)

        #expect(small.size.width <= medium.size.width)
        #expect(medium.size.height <= huge.size.height)
        #expect(huge.size.width == DrawerGeometry(count: 12).size.width)
        #expect(huge.size.height == DrawerGeometry(count: 12).size.height)
        // 무더기는 세로로만 자란다 — 폭은 종이 한 장이 들어갈 만큼으로 고정이다.
        #expect(small.size.width == huge.size.width)
    }

    /// 「원래 사이즈로 돌아온다」가 거짓말이 되지 않으려면, 되돌린 종이가
    /// 서랍 안에 **온전히** 들어가야 한다.
    @Test("되돌린 종이는 서랍 안을 넘지 않는다")
    func zoomedPaperFitsInside() {
        let plan = DrawerGeometry(count: 6)
        for paper in [
            CGSize(width: 260, height: 200),
            CGSize(width: 180, height: 140),
            CGSize(width: 900, height: 700),
        ] {
            let shown = plan.zoomed(paper: paper)
            #expect(shown.width <= plan.inner.width + 0.5)
            #expect(shown.height <= plan.inner.height + 0.5)
        }
    }

    @Test("작은 종이는 억지로 키우지 않는다 — 원래 크기가 원래 크기다")
    func smallPapersKeepTheirSize() {
        let plan = DrawerGeometry(count: 6)
        let small = CGSize(width: 180, height: 140)
        #expect(plan.zoomed(paper: small) == small)
    }

    @Test("줄일 때도 모양은 그대로다 — 늘어나면 그건 다른 종이다")
    func zoomKeepsTheAspectRatio() {
        let plan = DrawerGeometry(count: 6)
        let huge = CGSize(width: 900, height: 700)
        let shown = plan.zoomed(paper: huge)
        #expect(abs(shown.width / shown.height - huge.width / huge.height) < 0.001)
    }

    // MARK: 자리

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 860)

    @Test("아래에 자리가 있으면 왼쪽 위를 붙박고 아래로 자란다")
    func opensDownwardWhenThereIsRoom() {
        let closed = CGRect(x: 200, y: 500, width: 128, height: 108)
        let plan = DrawerGeometry(count: 6)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.minX == closed.minX)
        #expect(open.maxY == closed.maxY)
        #expect(open.size == plan.size)
    }

    /// 서랍의 기본 자리는 화면 **왼쪽 아래**다 (메모는 오른쪽 위부터, 달력은
    /// 왼쪽 위부터 쌓이므로 셋이 서로를 비켜간다). 거기서 아래로 자라려 들면
    /// 창이 화면 밖으로 내려가고, 안쪽으로 끌려 들어오면서 **폴더가 있던 자리를
    /// 통째로 떠난다** — 누른 자리와 열린 자리가 다르면 그건 열린 것이 아니다.
    @Test("아래가 모자라면 왼쪽 아래를 붙박고 위로 자란다")
    func opensUpwardAtTheBottomOfTheScreen() {
        let closed = CGRect(x: 40, y: 40, width: 128, height: 108)
        let plan = DrawerGeometry(count: 6)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.minX == closed.minX)
        #expect(open.minY == closed.minY)
        #expect(screen.contains(open))
    }

    @Test("오른쪽이 모자라면 오른쪽 변을 붙박고 왼쪽으로 자란다")
    func opensLeftwardAtTheRightEdge() {
        let closed = CGRect(x: screen.maxX - 140, y: 500, width: 128, height: 108)
        let plan = DrawerGeometry(count: 12)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.maxX == closed.maxX)
        #expect(screen.contains(open))
    }

    @Test("어느 구석에서 열어도 창은 화면 안에 있다")
    func alwaysOpensOnScreen() {
        let plan = DrawerGeometry(count: 12)
        for x in [screen.minX, screen.midX, screen.maxX - 128] {
            for y in [screen.minY, screen.midY, screen.maxY - 108] {
                let closed = CGRect(x: x, y: y, width: 128, height: 108)
                let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)
                #expect(screen.contains(open))
            }
        }
    }

    /// 종이는 서랍이 지금 보이는 **한가운데**로 날아간다. 펼친 창 전체로
    /// 날아가면 «줄어들며 사라지는» 것이 아니라 «커지며 사라지는» 것이 된다.
    @Test("날아 들어가는 자리는 언제나 닫힌 폴더만 하다")
    func landingSpotIsFolderSized() {
        let open = CGRect(x: 100, y: 100, width: 520, height: 366)
        let spot = DrawerGeometry.landingSpot(in: open)

        #expect(spot.size == DrawerGeometry.closedSize)
        #expect(spot.midX == open.midX)
        #expect(spot.midY == open.midY)
    }

    // MARK: 빈자리

    /// 손이 얹힐 자리를 얼마나 비워 두는가 — **판을 빈자리에 저당 잡히지 않는다.**
    ///
    /// 예전에는 이 값이 `sheet.height - band`(124pt) 였다. 얹힌 장을 **통째로**
    /// 드러내려던 값인데, 그러려면 창이 늘 그 124pt 를 비워 두고 있어야 했다 —
    /// 손을 치우면 판의 아래 4분의 1이 빈 채로 남았고, 한 장을 되돌렸을 때는
    /// 그 빈자리가 판의 절반이 됐다.
    ///
    /// 그림으로는 안 잡힌다. 렌더는 «손이 얹힌» 순간을 연출해 그리므로 그때는
    /// 빈자리가 마침 메워져 있고, 사람이 실제로 보는 «손을 치운» 순간은 그림에
    /// 남지 않는다. 그래서 숫자로 못 박는다.
    @Test("무더기가 판을 거의 다 쓴다 — 손이 얹힐 자리는 한 뼘이다")
    func thePileFillsThePanel() {
        // 한 뼘이란: 종이 한 장의 절반을 넘지 않는다. 예전의 124pt 는 여기서 걸린다.
        #expect(DrawerGeometry.lift < DrawerGeometry.sheet.height / 2)

        // 장수가 적을 때는 「종이 한 장이 들어갈 만큼」(`paperRoom`)이 창의
        // 바닥을 정하므로, 남는 자리도 그만큼까지는 어쩔 수 없다.
        let floor = DrawerGeometry.paperRoom.height - DrawerGeometry.sheet.height
        for count in 1...12 {
            let plan = DrawerGeometry(count: count)
            let pile = plan.offset(of: plan.stacked - 1) + DrawerGeometry.sheet.height
            #expect(plan.inner.height - pile <= max(DrawerGeometry.lift, floor) + 0.5)
        }
    }

    /// 벌어질 자리를 좁힌 값이 이번에는 **모자라면** 안 된다 — 손이 얹혔을 때
    /// 맨 아래 한 장이 판 밖으로 밀려나면 그건 자리를 아낀 것이 아니라 잘라낸 것이다.
    @Test("한 장이 벌어져도 무더기는 판 안에 있다")
    func theLiftedSheetStaysInside() {
        for count in 1...12 {
            let plan = DrawerGeometry(count: count)
            // 맨 위 한 장에 손이 얹히면 그 아래 전부가 `lift` 만큼 내려간다.
            let opened = plan.offset(of: plan.stacked - 1)
                + DrawerGeometry.lift + DrawerGeometry.sheet.height
            #expect(plan.inner.height >= opened - 0.5)
        }
    }

    /// 묻힌 한 장을 **보일 수 있는 만큼만** 그리는가.
    ///
    /// 종이를 늘 154pt 로 그려 두었더니, 손이 얹혀 6% 커질 때 **가려져 있던
    /// 아래쪽까지 같이 넓어져서** 다음 장들 오른쪽으로 색 띠 하나가 154pt 내내
    /// 삐져나왔다. 그림에서 그것은 고장이 아니라 «디자인» 처럼 보인다 —
    /// 무엇이 잘못됐는지 말해 주는 것은 숫자뿐이다.
    @Test("묻힌 장은 보일 수 있는 만큼만 그려진다")
    func buriedSheetsAreDrawnOnlyAsTallAsTheyShow() {
        let shown = DrawerGeometry.band + DrawerGeometry.lift
        #expect(DrawerGeometry.peek == shown)
        // 쉬고 있을 때 잘린 밑변이 드러나면 안 된다 — 띠보다는 커야 다음 장이 덮는다.
        #expect(DrawerGeometry.peek > DrawerGeometry.band)
        // 커져도 삐져나오는 것은 밑변 몇 pt 뿐이다.
        #expect(DrawerGeometry.peek * DrawerGeometry.hoverScale - shown < 6)
        // 그리고 **실제로 커지기는 한다** — 사람이 부탁한 것이 이 한 가지다.
        #expect(DrawerGeometry.hoverScale > 1)
    }

    /// 작아진 종이가 «원래 크기» 로 자라는 배율. 1 이면 자라지 않는 것이고,
    /// 그러면 누르는 동작이 아무 일도 안 한 것으로 보인다.
    ///
    /// **상한을 0.6 에서 0.8 로 올렸다.** 격자였을 때는 타일이 117pt 라 0.45
    /// 였는데, 무더기의 종이는 제목 한 줄이 **읽혀야** 하므로 그만큼 좁힐 수
    /// 없다 — 읽을 수 없는 글은 종이가 아니라 얼룩이다(`DrawerPaper`). 지금
    /// 0.72 는 1.39배로 자란다는 뜻이고, 그 정도면 «자랐다» 로 읽힌다.
    ///
    /// 이 시험이 지키는 것은 숫자가 아니라 «누른 것이 눈에 보이게 달라진다» 다.
    @Test("작아진 종이는 눈에 띄게 작다")
    func tilesAreVisiblySmaller() {
        let plan = DrawerGeometry(count: 6)
        let shrink = plan.shrink(paper: DrawerGeometry.paperRoom)
        #expect(shrink < 0.8)
        #expect(shrink > 0.2)
        // 자라는 배율로 다시 한 번 — 1.25배는 넘어야 동작이 보인다.
        #expect(1 / shrink > 1.25)
    }
}

/// 읽기만 하는 자리에서는 **체크상자가 글자로 보이면 안 된다** — 편집기는
/// 그것을 그려 주므로(`MarkdownStyler`), 서랍에서만 `- [x]` 로 보이면 같은
/// 메모가 두 곳에서 다른 물건이 된다 (§14.10).
@Suite("서랍의 종이가 적는 글")
struct DrawerPaperTextTests {

    @Test("체크상자는 기호가 된다")
    func checkboxesBecomeMarks() {
        #expect(DrawerText.plain("- [x] 우유") == "☑ 우유")
        #expect(DrawerText.plain("- [ ] 계란") == "☐ 계란")
        #expect(DrawerText.plain("  - [X] 세제") == "  ☑ 세제")
    }

    @Test("체크상자가 아닌 줄은 그대로 둔다 — 아는 척 고치지 않는다")
    func otherLinesAreUntouched() {
        #expect(DrawerText.plain("그냥 한 줄") == "그냥 한 줄")
        #expect(DrawerText.plain("- 목록 한 줄") == "- 목록 한 줄")
        #expect(DrawerText.plain("") == "")
    }
}
