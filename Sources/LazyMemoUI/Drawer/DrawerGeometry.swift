import CoreGraphics
import LazyMemoCore

/// 「서랍」의 판형 — **닫힌 크기와 열린 크기, 그리고 그 사이.**
///
/// 서랍은 창 하나인데 크기가 둘이다. 닫혀 있을 때(바탕화면 한구석의 작은
/// 탭)와 펼쳤을 때(찾기·폴더·목록이 선 판). 창 크기가 애니메이션의 시작과
/// 끝이므로 이 숫자들이 어긋나면 **펼치는 동작이 덜컥거린다** — 내용은
/// 이미 다 나왔는데 창이 아직 작아서 잘려 보이거나, 창만 커지고 안이 비어 보인다.
///
/// ## 무더기에서 목록으로
///
/// 앞선 판은 작아진 종이를 30pt 띠만큼씩 어긋나게 **겹쳐 쌓았다** (§16.2).
/// 첫 줄이 동시에 읽힌다는 것이 그 값이었는데, 실제로 쓰니 그 밖의 값이
/// 없었다 — 여덟 장이 넘으면 「그리고 N장 더」를 눌러야 했고, 손이 얹힌
/// 장이 잠깐 커지며 아래 것들을 밀어 판이 출렁였고, 한 장을 읽으려면 뒤가
/// 흐려지는 큰 종이가 떴다. 종이를 «흉내» 내느라 목록이 하는 일을 못 했다.
///
/// 지금은 **목록**이다. 한 줄에 색·제목·둘째 줄·시각이 있고, 넘치면 스크롤한다.
/// 종이의 재질(§14.5)은 판과 펼친 줄에 남긴다 — 겹침으로 말하지 않는다.
///
/// 뷰 밖의 순수 값인 이유는 `CalendarLayout` 과 같다. "서른 장일 때 창이
/// 화면 밖으로 나가는가" 같은 물음은 그림 한 장으로는 확인되지 않는다.
struct DrawerGeometry: Equatable {

    // MARK: 자리를 먹는 것들

    /// 닫힌 서랍 — **탭 하나.** 바탕화면에 늘 앉아 있으므로 작아야 한다.
    /// 비뚤게 깔린 종이 세 장을 그리던 앞선 판은 바탕화면에서 «흐트러진
    /// 카드» 로 보였다 — 몇 장인지는 두께가 아니라 숫자가 말한다.
    ///
    /// **168×48 이었다.** 바탕화면에서 눈에 안 띄었고, 종이를 끌어다 놓기에는
    /// 과녁이 종이(260×200)의 6분의 1이었다. 지금은 두 줄이다 — 이름과 장수,
    /// 그 밑에 **최근 두 장의 제목**. 탭을 열어 보기 전에 무엇이 들었는지
    /// 한 줄은 읽힌다 (§16.12).
    static let closedSize = CGSize(width: 232, height: 60)

    /// 펼친 판의 폭. 제목 한 줄과 둘째 줄, 그리고 손이 왔을 때의 조작 넷
    /// (꺼내기·펼치기·폴더·지우기)이 한 줄에 서는 폭이다.
    ///
    /// **372 였다.** 조작이 셋일 때의 값이라, 「꺼내기」를 줄에 글자로 세우니
    /// 제목이 스무 자에서 잘렸다. 찾기 줄·폴더 띠도 그만큼 숨을 쉰다.
    static let width: CGFloat = 440

    static let padding: CGFloat = 14
    static let headerHeight: CGFloat = 44
    /// 찾기 줄. 늘 있다 — 바닥에 숨겨 두던 앞선 판은 찾기가 있는 줄도 몰랐다.
    static let searchHeight: CGFloat = 40
    /// 폴더 띠. 「전체」와 폴더들, 그리고 새 폴더.
    static let foldersHeight: CGFloat = 38
    static let footerHeight: CGFloat = 32

    /// 목록의 한 줄. 제목 한 줄과 둘째 줄이 들어가는 높이다.
    ///
    /// 줄이 곧 **누르면 꺼내는 단추**가 되면서(§16.12) 두 줄 사이를 조금 벌렸다 —
    /// 과녁이 좁은 줄은 옆 줄이 눌린다 (`NoteControlLayout.spacing` 이 배운 것).
    static let rowHeight: CGFloat = 54
    /// 펼친 줄이 더 차지하는 높이 — 본문 몇 줄과 조작 한 줄. **본문 줄 수를 따른다.**
    /// 여섯 줄로 못 박아 두었더니 한 줄짜리 메모 밑이 텅 비었다 — 빈자리는 공짜가 아니다 (§16.3).
    static func expandedExtra(lines: Int) -> CGFloat {
        54 + CGFloat(min(max(lines, 1), DrawerText.maximumBodyLines)) * 17
    }
    /// 가장 길게 펼쳤을 때.
    static var expandedExtra: CGFloat { expandedExtra(lines: DrawerText.maximumBodyLines) }
    /// 목록이 비어 있어도 이만큼은 비워 둔다 — «여기 아무것도 없습니다» 가 설 자리다.
    static let minimumRows = 3

    /// 판형의 뼈대 — 목록을 뺀 나머지 높이.
    static var chrome: CGFloat {
        padding * 2 + headerHeight + searchHeight + foldersHeight + footerHeight
    }

    /// 목록에 실제로 놓이는 줄 수.
    var rows: Int
    /// 목록이 판보다 길어 스크롤하는가.
    var scrolls: Bool
    /// 펼친 창의 크기.
    var size: CGSize

    /// - Parameters:
    ///   - count: 지금 목록에 있는 줄 수.
    ///   - expanded: 한 줄을 펼쳐 두었는가.
    ///   - ceiling: 목록에 허락된 최대 높이 (`listCeiling(fitting:)`).
    init(
        count: Int, expanded: Bool = false, expandedLines: Int = DrawerText.maximumBodyLines,
        ceiling: CGFloat = .greatestFiniteMagnitude
    ) {
        rows = count
        let wanted = CGFloat(max(count, Self.minimumRows)) * Self.rowHeight
            + (expanded ? Self.expandedExtra(lines: expandedLines) : 0)
        let list = min(wanted, max(ceiling, Self.rowHeight * CGFloat(Self.minimumRows)))
        scrolls = wanted > list + 0.5
        size = CGSize(width: Self.width, height: Self.chrome + list)
    }

    /// 목록이 차지하는 높이.
    var listHeight: CGFloat { size.height - Self.chrome }

    /// **이 화면에서 목록이 가질 수 있는 최대 높이.**
    ///
    /// 상한이 없으면 창이 화면 위아래로 빠져나가고, 그러면 §16.4 가 고쳐 둔
    /// 고장(「폴더가 있던 자리를 통째로 떠난다」)이 그대로 돌아온다.
    static func listCeiling(fitting height: CGFloat) -> CGFloat {
        // 화면 위아래로 손톱만큼은 남긴다 — 메뉴바와 독에 닿는 창은 창이 아니라 벽이다.
        max(rowHeight * CGFloat(minimumRows), height - chrome - 96)
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
    /// **탭이 있던 모서리 하나는 그대로 남는다.**
    static func openFrame(anchoredAt closed: CGRect, size: CGSize, on screen: CGRect) -> CGRect {
        let downward = CGRect(
            x: closed.minX, y: closed.maxY - size.height, width: size.width, height: size.height
        )
        var frame = downward.minY >= screen.minY
            ? downward
            : CGRect(x: closed.minX, y: closed.minY, width: size.width, height: size.height)

        if frame.maxX > screen.maxX {
            frame.origin.x = closed.maxX - size.width
        }
        return FrameClamping.clamp(frame, into: screen)
    }

    /// 종이가 날아 들어가는 자리 — **서랍이 지금 보이는 그 한가운데.**
    ///
    /// 펼쳐져 있으면 창이 크므로 창 전체로 날아가면 «줄어들며 사라지는» 것이
    /// 아니라 «커지며 사라지는» 것이 된다. 언제나 닫힌 탭만 한 자리로 모은다.
    static func landingSpot(in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.midX - closedSize.width / 2,
            y: frame.midY - closedSize.height / 2,
            width: closedSize.width,
            height: closedSize.height
        )
    }
}
