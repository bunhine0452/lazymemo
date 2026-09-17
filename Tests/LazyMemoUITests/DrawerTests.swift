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
    @Test("스스로 물러난 것도 서랍에 있다 — 치워 둔 N장이 여기 있다")
    func tidiedPapersLandInTheDrawer() {
        #expect(DrawerContents.holds(paper(tidied: Date()), putAway: false))
    }

    /// 날짜가 붙은 것은 달력이 맡는다 (§7.2).
    @Test("날짜가 붙은 것은 달력이 맡는다 — 치웠어도 서랍에 없다")
    func scheduledMemosBelongToTheCalendar() {
        let dated = paper(due: CalendarDate(year: 2026, month: 9, day: 1))
        #expect(!DrawerContents.holds(dated, putAway: true))

        var tidiedAndDated = dated
        tidiedAndDated.tidied = Date()
        #expect(!DrawerContents.holds(tidiedAndDated, putAway: true))
    }

    /// 폴더는 자리를 정하지 않는다 — 이름표가 있어도 바탕화면에 나와 있으면
    /// 서랍에 없고, 날짜가 있으면 달력의 것이다.
    @Test("폴더 이름표는 자리를 바꾸지 않는다")
    func folderDoesNotDecidePlacement() {
        var labeled = paper("장보기")
        labeled.folder = "집"
        #expect(!DrawerContents.holds(labeled, putAway: false))
        #expect(DrawerContents.holds(labeled, putAway: true))
        labeled.due = CalendarDate(year: 2026, month: 9, day: 1)
        #expect(!DrawerContents.holds(labeled, putAway: true))
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
}

/// 「서랍」의 판형 — **그림 한 장으로는 확인되지 않는 것들.**
///
/// 서랍은 창 하나인데 크기가 둘이다(닫힌 탭·펼친 판). 그 사이를 창 프레임이
/// 오가므로, 숫자가 어긋나면 **펼치는 동작이 덜컥거리거나 목록이 창 밖으로
/// 잘려 나간다.** 화면 오른쪽 끝에서 열었을 때만 드러나는 종류라 렌더에는
/// 흔적이 남지 않는다.
@Suite("서랍의 판형")
struct DrawerGeometryTests {

    /// 두 줄(이름·장수 / 최근 두 장)이 들어가는 크기까지는 키웠다 (§16.12) —
    /// 그래도 펼친 판의 절반 남짓이고 종이(260×200)보다 작다.
    @Test("닫힌 탭은 작다 — 상주하는 물건이 창만 하면 그건 상주가 아니다")
    func closedTabIsSmall() {
        #expect(DrawerGeometry.closedSize.height <= 64)
        #expect(DrawerGeometry.closedSize.width <= DrawerGeometry.width * 0.55)
        #expect(DrawerGeometry.closedSize.width < 260)
    }

    @Test("비어 있어도 목록 자리는 세 줄만큼은 된다 — «아무것도 없습니다» 가 설 자리")
    func alwaysHasRoomForTheEmptyMessage() {
        let plan = DrawerGeometry(count: 0)
        #expect(plan.listHeight >= DrawerGeometry.rowHeight * CGFloat(DrawerGeometry.minimumRows) - 0.5)
        #expect(!plan.scrolls)
    }

    @Test("줄이 늘면 창도 한 줄씩 자란다")
    func windowGrowsPerRow() {
        let five = DrawerGeometry(count: 5)
        let six = DrawerGeometry(count: 6)
        #expect(abs((six.size.height - five.size.height) - DrawerGeometry.rowHeight) < 0.5)
        #expect(five.size.width == six.size.width)
        #expect(five.rows == 5)
    }

    @Test("펼친 줄만큼 창이 더 자란다")
    func expandedRowAddsRoom() {
        let closed = DrawerGeometry(count: 4)
        let open = DrawerGeometry(count: 4, expanded: true)
        #expect(abs((open.size.height - closed.size.height) - DrawerGeometry.expandedExtra) < 0.5)
    }

    /// 상한이 없으면 창이 화면 위아래로 빠져나가고, 그러면 §16.4 가 고쳐 둔
    /// 고장(「폴더가 있던 자리를 통째로 떠난다」)이 그대로 돌아온다.
    @Test("화면이 허락하는 것보다 자라지 않고, 그때부터 스크롤한다")
    func stopsAtTheScreenAndScrolls() {
        let ceiling = DrawerGeometry.listCeiling(fitting: 860)
        let few = DrawerGeometry(count: 4, ceiling: ceiling)
        let many = DrawerGeometry(count: 200, ceiling: ceiling)

        #expect(!few.scrolls)
        #expect(many.scrolls)
        #expect(many.listHeight <= ceiling + 0.5)
        #expect(many.size.height <= 860)
        // 조용히 자르지 않는다 — 줄 수는 그대로 안다.
        #expect(many.rows == 200)
    }

    @Test("작은 화면에서도 목록은 세 줄만큼은 남는다")
    func tinyScreensKeepMinimumRows() {
        let ceiling = DrawerGeometry.listCeiling(fitting: 300)
        #expect(ceiling >= DrawerGeometry.rowHeight * CGFloat(DrawerGeometry.minimumRows) - 0.5)
    }

    // MARK: 자리

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 860)
    private var closedSize: CGSize { DrawerGeometry.closedSize }

    @Test("아래에 자리가 있으면 왼쪽 위를 붙박고 아래로 자란다")
    func opensDownwardWhenThereIsRoom() {
        let closed = CGRect(origin: CGPoint(x: 200, y: 500), size: closedSize)
        let plan = DrawerGeometry(count: 6)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.minX == closed.minX)
        #expect(open.maxY == closed.maxY)
        #expect(open.size == plan.size)
    }

    /// 서랍의 기본 자리는 화면 **왼쪽 아래**다. 거기서 아래로 자라려 들면
    /// 창이 화면 밖으로 내려가고, 안쪽으로 끌려 들어오면서 **탭이 있던 자리를
    /// 통째로 떠난다** — 누른 자리와 열린 자리가 다르면 그건 열린 것이 아니다.
    @Test("아래가 모자라면 왼쪽 아래를 붙박고 위로 자란다")
    func opensUpwardAtTheBottomOfTheScreen() {
        let closed = CGRect(origin: CGPoint(x: 40, y: 40), size: closedSize)
        let plan = DrawerGeometry(count: 6)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.minX == closed.minX)
        #expect(open.minY == closed.minY)
        #expect(screen.contains(open))
    }

    @Test("오른쪽이 모자라면 오른쪽 변을 붙박고 왼쪽으로 자란다")
    func opensLeftwardAtTheRightEdge() {
        let closed = CGRect(origin: CGPoint(x: screen.maxX - closedSize.width - 12, y: 500), size: closedSize)
        let plan = DrawerGeometry(count: 12)
        let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)

        #expect(open.maxX == closed.maxX)
        #expect(screen.contains(open))
    }

    @Test("어느 구석에서 열어도 창은 화면 안에 있다")
    func alwaysOpensOnScreen() {
        let plan = DrawerGeometry(count: 12, ceiling: DrawerGeometry.listCeiling(fitting: screen.height))
        for x in [screen.minX, screen.midX, screen.maxX - closedSize.width] {
            for y in [screen.minY, screen.midY, screen.maxY - closedSize.height] {
                let closed = CGRect(origin: CGPoint(x: x, y: y), size: closedSize)
                let open = DrawerGeometry.openFrame(anchoredAt: closed, size: plan.size, on: screen)
                #expect(screen.contains(open))
            }
        }
    }

    /// 종이는 서랍이 지금 보이는 **한가운데**로 날아간다. 펼친 창 전체로
    /// 날아가면 «줄어들며 사라지는» 것이 아니라 «커지며 사라지는» 것이 된다.
    @Test("날아 들어가는 자리는 언제나 닫힌 탭만 하다")
    func landingSpotIsTabSized() {
        let open = CGRect(x: 100, y: 100, width: 372, height: 500)
        let spot = DrawerGeometry.landingSpot(in: open)

        #expect(spot.size == DrawerGeometry.closedSize)
        #expect(spot.midX == open.midX)
        #expect(spot.midY == open.midY)
    }
}

/// 읽기만 하는 자리에서는 **체크상자가 글자로 보이면 안 된다** — 편집기는
/// 그것을 그려 주므로(`MarkdownStyler`), 서랍에서만 `- [x]` 로 보이면 같은
/// 메모가 두 곳에서 다른 물건이 된다 (§14.10).
@Suite("서랍의 줄이 적는 글")
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
