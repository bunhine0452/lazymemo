import CoreGraphics
import LazyMemoCore

/// 「서랍」의 판형 — **닫힌 크기와 열린 크기, 그리고 그 사이.**
///
/// 서랍은 창 하나인데 크기가 셋이다. 닫혀 있을 때(종이 끝만 삐죽), 펼쳤을 때
/// (작아진 종이들이 **겹쳐 쌓인** 무더기), 그리고 한 장을 원래 크기로 되돌렸을 때. 창 크기가 애니메이션의
/// 시작과 끝이므로 이 숫자들이 어긋나면 **펼치는 동작이 덜컥거린다** — 내용은
/// 이미 다 나왔는데 창이 아직 작아서 잘려 보이거나, 창만 커지고 안이 비어 보인다.
///
/// 뷰 밖의 순수 값인 이유는 `CalendarLayout` 과 같다. "네 장일 때 창이 화면
/// 밖으로 나가는가" 같은 물음은 그림 한 장으로는 확인되지 않는다 — 화면 오른쪽
/// 끝에 서랍을 두고 열어 봐야 드러나고, 그 상황은 렌더에 남지 않는다.
struct DrawerGeometry: Equatable {

    // MARK: 자리를 먹는 것들

    /// 닫힌 서랍. 바탕화면에 늘 앉아 있으므로 **아이콘만 하다** — 이보다 크면
    /// 상주하는 물건이 아니라 열어 둔 창이 된다.
    static let closedSize = CGSize(width: 128, height: 96)

    /// 무더기에 놓인 종이 한 장.
    ///
    /// 260×200 짜리 종이의 비율(1.3:1)을 그대로 줄인다. 비율이 달라지면 커질
    /// 때 종이가 늘어나는 것으로 보이고, 그것은 종이가 아니라 고무다.
    ///
    /// 폭은 안쪽 상자(종이 한 장이 들어갈 260)보다 좁다. 남는 60pt 는 장식이
    /// 아니라 **손이 얹힌 장이 밀려 나올 자리**다.
    ///
    /// 213 까지 키워 봤다가 되돌렸다 — 시험(`tilesAreVisiblySmaller`)이 잡았다.
    /// 그때 자라는 배율이 1.22배였는데, 그 정도로는 **누른 것이 자란 것으로
    /// 보이지 않는다.** 지금은 1.30배다.
    static let sheet = CGSize(width: 200, height: 154)

    /// **겹쳐 쌓을 때 한 장이 드러내는 띠.**
    ///
    /// 이 숫자가 이 판형의 전부다. 예전에는 격자였다 — 타일이 나란히 놓이고
    /// 저마다 제목 한 줄을 들고 있었는데, 여덟 장이 **색으로만 갈렸다.**
    /// 원하는 것을 찾으려면 하나씩 눌러 봐야 했고, 그건 메뉴 목록보다 나쁘다
    /// (메뉴는 여덟 줄을 한눈에 보여주고 클릭도 한 번 적다).
    ///
    /// 겹쳐 쌓으면 **첫 줄이 동시에 다 읽힌다.** 그리고 그 모양이 곧 «밀어 둔
    /// 종이 무더기» 라, §16.2 가 스스로 걱정하던 「격자로 읽힌다」를 벗어난다.
    /// 띠는 제목 한 줄이 읽히는 만큼이다 — 더 좁히면 글자가 잘리고, 넓히면
    /// 여덟 장이 화면을 넘는다.
    static let band: CGFloat = 30

    /// **손이 얹힌 장이 잠깐 커지는 배율.** 사람이 부탁한 그 동작이다 —
    /// "호버시 잠깐 커지게".
    ///
    /// 6%는 작아 보이지만 이 장에서는 셋이 한꺼번에 온다: 폭과 높이가 자라고,
    /// 옆으로 8pt 밀려 나오고, 아래 것들이 `lift` 만큼 내려가 **띠가 30pt 에서
    /// 80pt 남짓으로 벌어진다.** 겹친 무더기에서 한 장을 반쯤 빼 보는 손짓이다.
    static let hoverScale: CGFloat = 1.06

    /// 손이 얹힌 장이 벌어질 자리 — **아래 것들이 밀려 내려가는 거리.**
    ///
    /// 예전에는 이 값이 `sheet.height - band`(124pt) 였다. 얹힌 장을 **통째로**
    /// 드러내려던 값인데, 그러려면 창이 그 124pt 를 늘 비워 두고 있어야 했다 —
    /// 아무것도 안 얹혔을 때 판의 아래 4분의 1이 빈 채로 남았고, 한 장을
    /// 되돌렸을 때는 그 빈자리가 판의 절반이 됐다. 「원래 크기로 펼치기」가
    /// 이미 통째로 보여주는데, 손만 얹어도 통째로 보여주려다 **판 전체를
    /// 빈자리에 저당 잡힌 것**이다.
    ///
    /// 지금은 제목 아래 두 줄이 드러날 만큼만 연다. 그것이 «이 장이 무엇인가» 에
    /// 답하는 최소한이고, 나머지는 눌렀을 때의 몫이다 (§16.3).
    static let lift: CGFloat = 44

    /// **무더기에 묻힌 한 장이 실제로 그려지는 높이.**
    ///
    /// 겹쳐 놓인 장은 다음 장이 덮으므로 띠(30pt)밖에 보이지 않고, 손이 얹히면
    /// 벌어진 만큼(`lift`)까지 보인다. 그런데 종이를 늘 154pt 로 그려 두었더니
    /// 손이 얹혀 6% 커질 때 **가려져 있던 아래쪽까지 같이 넓어져서**, 다음 장들
    /// 오른쪽으로 색 띠 하나가 154pt 내내 삐져나왔다 — 덮인 줄 알았던 몸통이
    /// 옆으로 빠져나온 것이다.
    ///
    /// 그래서 **보일 수 있는 만큼만** 그린다 — 띠에 벌어질 자리를 더한 값이
    /// 곧 이 한 장이 세상에 드러낼 수 있는 전부다. 쉬고 있을 때는 다음 장이
    /// `lift` 만큼을 덮으므로 잘린 밑변이 보이지 않고, 손이 얹혀 6% 커져도
    /// 삐져나오는 것은 밑변 4pt 뿐이다.
    static var peek: CGFloat { band + lift }

    static let padding: CGFloat = 14
    /// 바닥의 한 줄 — 방금 한 일이나 넣는 법을 적는다.
    static let footerHeight: CGFloat = 22

    /// 스크롤 없이 보이는 장수. 이보다 쌓이면 서랍이 화면을 넘는다.
    static let visible = 8

    /// **한 장을 원래 크기로 되돌릴 자리.** 펼친 서랍의 안쪽은 언제나 종이
    /// 한 장이 들어갈 만큼은 된다 — 아니면 「원래 사이즈로 돌아온다」가 거짓말이
    /// 되고, 되돌린 종이가 서랍 밖으로 잘려 나간다.
    ///
    /// 기본 종이 크기(§7 의 260×200)와 같다.
    static let paperRoom = CGSize(width: 260, height: 200)

    /// 무더기에 실제로 놓이는 장수 (스크롤 없이 보이는 만큼).
    var stacked: Int
    /// 스크롤해야 닿는 장이 있는가.
    var scrolls: Bool
    /// 펼친 창의 크기.
    var size: CGSize

    init(count: Int) {
        let papers = max(count, 1)
        stacked = min(Self.visible, papers)
        scrolls = papers > Self.visible

        // 겹친 무더기의 높이 — 맨 아래 한 장은 통째로 보이고, 그 위의 것들은
        // 띠만큼씩 어긋나 있다.
        // 벌어질 자리(`lift`)를 늘 비워 둔다 — 손이 왔을 때 창이 커지면 그건
        // 「열린다」가 아니라 「창이 튄다」로 보인다. 다만 그 값은 판의 4분의 1이
        // 아니라 **한 뼘**이어야 한다. 빈자리는 공짜가 아니다.
        let pile = Self.sheet.height + Self.band * CGFloat(stacked - 1) + Self.lift
        // 무더기가 짧아도 창은 종이 한 장만큼은 된다 (`paperRoom`).
        let inner = CGSize(
            width: max(Self.sheet.width, Self.paperRoom.width),
            height: max(pile, Self.paperRoom.height)
        )
        size = CGSize(
            width: inner.width + Self.padding * 2,
            height: inner.height + Self.padding * 2 + Self.footerHeight
        )
    }

    /// 무더기와 되돌린 종이가 함께 쓰는 안쪽 상자.
    var inner: CGSize {
        CGSize(
            width: size.width - Self.padding * 2,
            height: size.height - Self.padding * 2 - Self.footerHeight
        )
    }

    /// 무더기의 `index` 번째 종이가 놓이는 세로 자리.
    func offset(of index: Int) -> CGFloat { Self.band * CGFloat(index) }

    /// 한 장을 되돌릴 크기 — **그 종이가 바탕화면에서 갖던 크기.**
    ///
    /// 서랍 안쪽보다 큰 종이는 안쪽에 맞춰 줄인다. 비율은 지킨다 — 원래 크기로
    /// 돌아온다면서 모양이 달라지면 그건 다른 종이다.
    func zoomed(paper: CGSize) -> CGSize {
        guard paper.width > 0, paper.height > 0 else { return Self.paperRoom }
        let room = inner
        let scale = min(1, min(room.width / paper.width, room.height / paper.height))
        return CGSize(width: paper.width * scale, height: paper.height * scale)
    }

    /// 작아진 종이의 배율. 되돌릴 때 몇 배로 자라는지가 곧 이 동작의 크기다.
    func shrink(paper: CGSize) -> CGFloat {
        let full = zoomed(paper: paper)
        guard full.width > 0 else { return 1 }
        return Self.sheet.width / full.width
    }

    /// 펼칠 때 창이 놓이는 자리 — **자랄 데가 있는 쪽으로 자란다.**
    ///
    /// 처음에는 왼쪽 위만 붙박아 두었다. 사람이 방금 누른 자리에서 자라야
    /// "그것이 열렸다" 로 읽히기 때문이다. 그런데 **서랍의 기본 자리가 화면
    /// 왼쪽 아래**라(메모는 오른쪽 위부터, 달력은 왼쪽 위부터 쌓이므로 셋이
    /// 서로를 비켜간다) 아래로 자랄 자리가 없었다 — 창이 화면 밖으로 내려가고,
    /// 안쪽으로 끌려 들어오면서 **폴더가 있던 자리를 통째로 떠났다.**
    /// 누른 자리와 열린 자리가 다르면 그건 열린 것이 아니라 딴 창이 뜬 것이다.
    ///
    /// 그래서 방향을 고른다. 아래에 자리가 있으면 왼쪽 **위**를 붙박고 아래로,
    /// 없으면 왼쪽 **아래**를 붙박고 위로. 좌우도 같다. 어느 쪽으로 자라든
    /// **폴더가 있던 모서리 하나는 그대로 남는다.**
    static func openFrame(anchoredAt closed: CGRect, size: CGSize, on screen: CGRect) -> CGRect {
        // 아래로 (왼쪽 위 고정) / 위로 (왼쪽 아래 고정).
        let downward = CGRect(
            x: closed.minX, y: closed.maxY - size.height, width: size.width, height: size.height
        )
        var frame = downward.minY >= screen.minY
            ? downward
            : CGRect(x: closed.minX, y: closed.minY, width: size.width, height: size.height)

        // 오른쪽으로 자랄 자리가 없으면 오른쪽 변을 붙박고 왼쪽으로 자란다.
        if frame.maxX > screen.maxX {
            frame.origin.x = closed.maxX - size.width
        }
        return FrameClamping.clamp(frame, into: screen)
    }

    /// 종이가 날아 들어가는 자리 — **서랍이 지금 보이는 그 한가운데.**
    ///
    /// 펼쳐져 있으면 창이 크므로 창 전체로 날아가면 «줄어들며 사라지는» 것이
    /// 아니라 «커지며 사라지는» 것이 된다. 언제나 닫힌 폴더만 한 자리로 모은다.
    static func landingSpot(in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.midX - closedSize.width / 2,
            y: frame.midY - closedSize.height / 2,
            width: closedSize.width,
            height: closedSize.height
        )
    }
}
