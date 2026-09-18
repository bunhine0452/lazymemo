import CoreGraphics
import Foundation

/// 종이가 **글에 맞춰 자라는** 규칙 (설계문서 §7.1 — 「불편은 곧 실패다」).
///
/// 기본 종이는 260×200 이다. 그 안에 든 글이 여덟 줄을 넘는 순간부터 사람은
/// 자기가 방금 붙여 넣은 것을 **못 본다** — 스크롤 막대는 「더 있다」고 말할 뿐
/// 무엇이 있는지는 말하지 않는다. 긴 글을 붙였을 때, 비서가 정리한 결과가
/// 돌아왔을 때, 다른 기기에서 자란 파일이 넘어왔을 때, 종이는 한 번 자란다.
///
/// **줄이지는 않는다.** 사람이 크기를 정한 종이를 앱이 되돌리는 것은 조작이
/// 아니라 싸움이고(§7.1), 글을 지웠다고 창이 쪼그라들면 다음에 칠 자리가
/// 사라진다. 자라는 쪽으로만, 화면의 몫 안에서만 움직인다.
///
/// AppKit 밖의 순수 계산으로 둔 이유는 화면·창 없이 시험할 수 있게 하기 위해서다
/// (`PaperFitTests`) — 창을 실제로 띄워서야 확인되는 규칙은 아무도 확인하지 않는다.
enum PaperFit {
    /// 편히 읽히는 폭의 한계. 이보다 넓어지면 눈이 줄 끝에서 다음 줄 머리를 못 찾는다.
    static let comfortableWidth: CGFloat = 560

    /// 화면에서 종이 한 장이 가질 수 있는 몫. 나머지는 사람이 쓰던 창의 자리다.
    static let screenShare: CGFloat = 0.7

    /// 이만큼 넘쳐야 자란다. 반올림 한두 점에 창이 움찔거리면 그것이 더 불편하다.
    static let slack: CGFloat = 6

    /// **사람이 손으로 크기를 정한 종이**는 이만큼(대여섯 줄) 넘칠 때만 자란다.
    /// 작게 접어 둔 것은 그러라고 접은 것이다 — 한 줄 넘쳤다고 펴면 싸움이 된다.
    static let handSlack: CGFloat = 96

    /// 한 문단이 평균 이만큼 접히면 「줄이 너무 길다」로 본다. 그때만 폭을 넓힌다.
    static let wrapThreshold: Double = 2

    /// 창이 이보다 작아지지 않는다 (`DesktopLevelWindow.minSize`).
    static let minimumSize = CGSize(width: 180, height: 120)

    /// 지금 이 종이의 형편. 전부 재 온 값이다 — 여기서 화면을 다시 묻지 않는다.
    struct Paper: Equatable {
        /// 지금 창.
        var frame: CGRect
        /// 글이 차지한 높이 — 텍스트 뷰의 `usedRect` 에 위아래 여백을 더한 것.
        var textHeight: CGFloat
        /// 글 칸 **밖**이 먹는 높이 — 자리 카드·가는 길·사진·링크·꼬리.
        var chrome: CGFloat
        /// 하드 줄바꿈으로 나뉜 문단 수. 줄이 긴지 판단하는 분모다.
        var paragraphs: Int
        /// 한 줄의 키 (괘선 간격).
        var lineHeight: CGFloat
        /// 사람이 손으로 크기를 정한 적이 있는가.
        var userSized: Bool

        init(
            frame: CGRect, textHeight: CGFloat, chrome: CGFloat,
            paragraphs: Int, lineHeight: CGFloat, userSized: Bool = false
        ) {
            self.frame = frame
            self.textHeight = textHeight
            self.chrome = chrome
            self.paragraphs = paragraphs
            self.lineHeight = lineHeight
            self.userSized = userSized
        }
    }

    /// 이 종이가 가야 할 새 자리. 그대로 두어야 하면 `nil`.
    ///
    /// - Parameter screen: 화면의 쓸 수 있는 구역 (`NSScreen.visibleFrame`).
    static func fit(_ paper: Paper, on screen: CGRect) -> CGRect? {
        guard screen.width > 0, screen.height > 0 else { return nil }
        guard paper.textHeight > 0, paper.chrome >= 0 else { return nil }

        let needed = paper.textHeight + paper.chrome
        let margin = paper.userSized ? handSlack : slack
        // 넘치지 않으면 아무것도 하지 않는다. **줄이지 않는다** — 글이 짧아졌다고
        // 창이 쪼그라들면 다음에 칠 자리가 사라진다.
        guard needed > paper.frame.height + margin else { return nil }

        var width = paper.frame.width
        var textHeight = paper.textHeight

        // 줄이 너무 길면 **폭을 먼저** 준다. 260pt 폭에서 한 문단이 열 줄로 접히는
        // 글은 높이만 늘려 봐야 가늘고 긴 띠가 될 뿐이다.
        if let widened = widerWidth(paper, on: screen) {
            // 넓힌 만큼 접힘이 풀린다 — 대략 폭에 반비례한다. 한 줄은 덤으로 둔다
            // (마지막 줄은 대개 꽉 차지 않는다). 어긋난 만큼은 다음 재기가 고친다.
            textHeight = textHeight * (width / widened) + paper.lineHeight
            width = widened
        }

        let cap = max(minimumSize.height, min(screen.height * screenShare, screen.height))
        let height = max(paper.frame.height, min(textHeight + paper.chrome, cap))
        let size = CGSize(width: max(width, minimumSize.width), height: height)

        // **윗변을 고정한다.** 사람이 둔 자리는 종이의 머리이지 발이 아니다 —
        // 아래로 자라야 읽던 첫 줄이 그 자리에 남는다.
        var origin = CGPoint(x: paper.frame.minX, y: paper.frame.maxY - size.height)
        // 아래로 넘치면 그만큼 통째로 올린다. 화면 밖으로 자란 종이는 안 자란 것만 못하다.
        if origin.y < screen.minY { origin.y = screen.minY }
        if origin.y + size.height > screen.maxY { origin.y = screen.maxY - size.height }
        if origin.x + size.width > screen.maxX { origin.x = screen.maxX - size.width }
        if origin.x < screen.minX { origin.x = screen.minX }

        let result = CGRect(origin: origin, size: size)
        return result.equalTo(paper.frame) ? nil : result
    }

    /// 넓혀야 할 폭. 줄이 길지 않거나 이미 충분히 넓으면 `nil`.
    private static func widerWidth(_ paper: Paper, on screen: CGRect) -> CGFloat? {
        guard paper.lineHeight > 0 else { return nil }
        let wrapped = Double(paper.textHeight / paper.lineHeight)
        let ratio = wrapped / Double(max(paper.paragraphs, 1))
        guard ratio >= wrapThreshold else { return nil }

        let target = min(comfortableWidth, screen.width)
        guard target > paper.frame.width + slack else { return nil }
        return target
    }

    /// 이 크기가 **앱이 정한 것**인가 — 아니면 사람이 손으로 잡아 늘린 것이다.
    ///
    /// `layout.json` 에는 「누가 정했는가」가 없다. 새 열쇠를 넣어 파일 규격을
    /// 바꾸는 대신 크기로 짐작한다: 앱이 내놓는 크기는 몇 가지뿐이라(계단으로
    /// 내려앉는 260×200, 지도가 앉은 320, 가는 길이 선 것) 그 밖의 값은 사람의
    /// 손이거나 앱이 이미 글에 맞춰 늘려 둔 것이고, **둘 다 줄이면 안 되는 것**이다.
    static func looksAppSized(_ size: CGSize, defaults: [CGSize]) -> Bool {
        defaults.contains { abs($0.width - size.width) < 1 && abs($0.height - size.height) < 1 }
    }
}
