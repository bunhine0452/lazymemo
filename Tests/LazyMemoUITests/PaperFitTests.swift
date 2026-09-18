import CoreGraphics
import Testing
@testable import LazyMemoUI

/// 종이가 글에 맞춰 자라는 규칙 (`PaperFit`).
///
/// 창을 실제로 띄워서야 확인되는 규칙은 아무도 확인하지 않는다 — 그래서
/// 계산을 AppKit 밖에 두고 여기서 못박는다. 특히 **줄지 않는다**는 약속은
/// 한 번 깨지면 사람이 맞춰 둔 종이가 글을 지울 때마다 쪼그라든다.
@Suite("종이가 글에 맞춰 자란다")
struct PaperFitTests {
    /// 1440×900 짜리 화면 하나.
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 860)
    /// 기본 종이 — 오른쪽 위 계단 자리.
    let standard = CGRect(x: 1140, y: 620, width: 260, height: 200)

    private func paper(
        _ frame: CGRect? = nil,
        text: CGFloat,
        chrome: CGFloat = 20,
        paragraphs: Int = 40,
        userSized: Bool = false
    ) -> PaperFit.Paper {
        PaperFit.Paper(
            frame: frame ?? standard, textHeight: text, chrome: chrome,
            paragraphs: paragraphs, lineHeight: 22, userSized: userSized
        )
    }

    @Test("글이 들어가면 그대로 둔다")
    func staysWhenTextFits() {
        #expect(PaperFit.fit(paper(text: 120), on: screen) == nil)
    }

    @Test("한두 점 넘치는 것으로는 움직이지 않는다 — 창이 움찔거리면 그게 더 불편하다")
    func ignoresRoundingOverflow() {
        #expect(PaperFit.fit(paper(text: 183), on: screen) == nil)
    }

    @Test("긴 글을 붙이면 아래로 자란다 — 윗변은 그 자리에")
    func growsDownward() {
        let fitted = PaperFit.fit(paper(text: 500), on: screen)
        let grown = try! #require(fitted)
        #expect(grown.height == 520)
        #expect(grown.maxY == standard.maxY)   // 읽던 첫 줄이 제자리에 남는다
        #expect(grown.minX == standard.minX)
    }

    @Test("화면 밖으로는 안 자란다 — 넘치면 통째로 올린다")
    func shiftsUpInsteadOfLeavingTheScreen() {
        let low = CGRect(x: 100, y: 20, width: 260, height: 200)
        let grown = try! #require(PaperFit.fit(paper(low, text: 500), on: screen))
        #expect(grown.minY == screen.minY)
        #expect(grown.height == 520)
        #expect(screen.contains(grown))
    }

    @Test("화면 몫(70%)을 넘지 않는다 — 나머지는 스크롤이 맡는다")
    func capsAtScreenShare() {
        let grown = try! #require(PaperFit.fit(paper(text: 9000, paragraphs: 400), on: screen))
        #expect(grown.height == (screen.height * PaperFit.screenShare).rounded(.down) || grown.height <= screen.height * PaperFit.screenShare + 1)
        #expect(grown.height <= screen.height * PaperFit.screenShare + 0.5)
    }

    @Test("줄이지 않는다 — 글이 짧아졌다고 종이가 쪼그라들면 다음에 칠 자리가 없다")
    func neverShrinks() {
        let big = CGRect(x: 200, y: 200, width: 420, height: 600)
        #expect(PaperFit.fit(paper(big, text: 80), on: screen) == nil)
    }

    // MARK: 사람이 정한 크기

    @Test("손으로 잡아 늘린 종이는 조금 넘치는 것으로 안 자란다")
    func respectsTheHand() {
        let byHand = paper(text: 240, userSized: true)   // 40pt 넘침
        #expect(PaperFit.fit(byHand, on: screen) == nil)
    }

    @Test("그래도 크게 넘치면 자란다 — 못 보는 글이 반이면 접어 둔 뜻도 아니다")
    func growsWhenOverflowIsBad() {
        let byHand = paper(text: 600, userSized: true)
        #expect(PaperFit.fit(byHand, on: screen) != nil)
    }

    // MARK: 폭

    @Test("줄이 아주 길면 폭도 편한 데까지 넓힌다")
    func widensForLongLines() {
        // 문단 셋이 400pt 로 접혔다 = 한 문단이 여섯 줄. 폭이 모자란다는 뜻이다.
        let wrapped = paper(text: 400, paragraphs: 3)
        let grown = try! #require(PaperFit.fit(wrapped, on: screen))
        #expect(grown.width == PaperFit.comfortableWidth)
        // 넓힌 만큼 접힘이 풀리므로 높이는 400 그대로 가지 않는다.
        #expect(grown.height < 420)
    }

    @Test("줄이 짧으면 폭은 그대로 — 목록은 넓힌다고 읽기 쉬워지지 않는다")
    func keepsWidthForShortLines() {
        let list = paper(text: 500, paragraphs: 23)   // 한 문단이 한 줄
        let grown = try! #require(PaperFit.fit(list, on: screen))
        #expect(grown.width == standard.width)
    }

    @Test("넓혀도 화면 오른쪽으로 넘치지 않는다")
    func widensInsideTheScreen() {
        let atEdge = CGRect(x: screen.maxX - 280, y: 500, width: 260, height: 200)
        let grown = try! #require(PaperFit.fit(paper(atEdge, text: 400, paragraphs: 3), on: screen))
        #expect(grown.maxX <= screen.maxX)
        #expect(screen.contains(grown))
    }

    // MARK: 누가 정한 크기인가

    @Test("앱이 내놓는 크기는 앱의 것, 나머지는 사람의 것")
    func tellsAppSizeFromHandSize() {
        let sizes = [CGSize(width: 260, height: 200), CGSize(width: 260, height: 320)]
        #expect(PaperFit.looksAppSized(CGSize(width: 260, height: 200), defaults: sizes))
        #expect(PaperFit.looksAppSized(CGSize(width: 260, height: 320), defaults: sizes))
        #expect(!PaperFit.looksAppSized(CGSize(width: 420, height: 380), defaults: sizes))
    }

    @Test("재지 못한 종이는 건드리지 않는다 — 0 은 「모른다」이지 「비었다」가 아니다")
    func doesNothingWithoutMeasurements() {
        #expect(PaperFit.fit(paper(text: 0), on: screen) == nil)
        #expect(PaperFit.fit(paper(text: 500), on: .zero) == nil)
    }
}
