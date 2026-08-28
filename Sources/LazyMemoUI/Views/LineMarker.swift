import AppKit

/// 줄머리 표시 — **글자가 아니라 여백에 그린다.**
///
/// `- [ ] 우유` 를 치면 파일에는 그대로 남지만 화면에는 진짜 체크상자가
/// 보여야 한다. 그런데 정본이 마크다운이라(D4) 글자를 바꿔 끼울 수는 없다
/// — 바꾸는 순간 파일도, 커서도, 되돌리기도 어긋난다.
///
/// 그래서 마커 글자는 눌러 감추고 **비워 둔 왼쪽 여백에 직접 그린다.**
/// 문단 들여쓰기가 그 자리를 만들어 주므로 줄이 넘어가도 글이 가지런하다.
/// 감춘 원문은 커서가 그 줄에 오면 되돌아온다 (`MarkdownStyler`).
enum LineMarker: Int {
    case bullet = 0
    case quote = 1
    case unchecked = 2
    case checked = 3

    /// 이 표시가 쓰는 왼쪽 여백. 문단 들여쓰기와 같은 값이어야 한다.
    var gutter: CGFloat {
        switch self {
        case .bullet, .quote: 15
        case .unchecked, .checked: 21
        }
    }

    var isCheckbox: Bool { self == .unchecked || self == .checked }

    /// 화면 밖 렌더에서 여백 그림 대신 끼워 넣는 글리프 (`MarkdownStyler`).
    var previewGlyph: String {
        switch self {
        case .bullet: "•  "
        case .quote: "▏ "
        case .unchecked: "☐ "
        case .checked: "☑ "
        }
    }

    /// 그릴 자리. `origin` 은 글이 시작되기 전 여백의 왼쪽 위, `centerY` 는 글자 높이의 한가운데.
    func box(at left: CGFloat, centerY: CGFloat, lineHeight: CGFloat) -> NSRect {
        switch self {
        case .unchecked, .checked:
            let side: CGFloat = 12.5
            return NSRect(x: left + 1, y: centerY - side / 2, width: side, height: side)
        case .bullet:
            let side: CGFloat = 4.5
            return NSRect(x: left + 4, y: centerY - side / 2, width: side, height: side)
        case .quote:
            let width: CGFloat = 2.5
            let height = max(lineHeight - 4, 8)
            return NSRect(x: left + 2, y: centerY - height / 2, width: width, height: height)
        }
    }

    func draw(at left: CGFloat, centerY: CGFloat, lineHeight: CGFloat, ink: NSColor) {
        let rect = box(at: left, centerY: centerY, lineHeight: lineHeight)

        switch self {
        case .bullet:
            ink.withAlphaComponent(0.38).setFill()
            NSBezierPath(ovalIn: rect).fill()

        case .quote:
            // 인용은 글이 아니라 **옆에서 데려온 말**이다. 세로선 하나면 충분하다.
            ink.withAlphaComponent(0.22).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.25, yRadius: 1.25).fill()

        case .unchecked, .checked:
            let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), xRadius: 3.5, yRadius: 3.5)
            outline.lineWidth = 1.2

            if self == .checked {
                // 끝낸 일은 조용히 채운다. 색으로 자랑하지 않는다 (철학 4).
                ink.withAlphaComponent(0.13).setFill()
                outline.fill()
                ink.withAlphaComponent(0.30).setStroke()
                outline.stroke()
                drawCheck(in: rect, ink: ink)
            } else {
                ink.withAlphaComponent(0.32).setStroke()
                outline.stroke()
            }
        }
    }

    private func drawCheck(in rect: NSRect, ink: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + rect.width * 0.26, y: rect.midY + rect.height * 0.02))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.44, y: rect.midY + rect.height * 0.22))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.76, y: rect.midY - rect.height * 0.22))
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        ink.withAlphaComponent(0.58).setStroke()
        path.stroke()
    }
}

extension NSAttributedString.Key {
    /// 이 줄에 그릴 `LineMarker` 의 raw 값. 마커 글자가 아니라 **내용 구간**에 붙인다 —
    /// 감춘 글자는 글꼴이 0.01pt 라 기준선을 물어볼 수 없기 때문이다.
    static let lineMarker = NSAttributedString.Key("lazymemo.lineMarker")
}
