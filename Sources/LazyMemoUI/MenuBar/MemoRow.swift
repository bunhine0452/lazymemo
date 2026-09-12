import AppKit
import LazyMemoCore

/// 메뉴 안 메모 한 줄의 자리.
///
/// 좌표를 뷰 밖에 두는 이유는 `MonthGridGeometry` 와 같다 — 휴지통을 몇 픽셀
/// 어긋나게 놓으면 "눌렀는데 안 지워진다" 가 되고, 그건 화면을 봐서는 모른다.
struct MemoRowGeometry {
    /// 한 줄의 높이. 메뉴에서 여덟 줄이 서므로 함부로 키울 수는 없지만,
    /// 30pt 는 휴지통(22pt)이 위아래로 4pt 씩 밖에 안 남아 **줄을 열려다
    /// 지우는** 일이 생기는 높이였다.
    static let height: CGFloat = 32
    static let width: CGFloat = 320

    /// 종이 색 점.
    static let dotDiameter: CGFloat = 8
    /// 휴지통이 차지하는 정사각형 (`Theme.touch`).
    static let trashSide: CGFloat = 24

    private static let leading: CGFloat = 13
    private static let trailing: CGFloat = 9
    private static let gap: CGFloat = 9

    let bounds: CGRect
    /// 오른쪽에 적히는 시간 글자의 폭. 없으면 0.
    let timeWidth: CGFloat

    init(
        width: CGFloat = MemoRowGeometry.width,
        height: CGFloat = MemoRowGeometry.height,
        timeWidth: CGFloat = 0
    ) {
        self.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        self.timeWidth = timeWidth
    }

    var dot: CGRect {
        CGRect(
            x: Self.leading,
            y: bounds.midY - Self.dotDiameter / 2,
            width: Self.dotDiameter,
            height: Self.dotDiameter
        )
    }

    var trash: CGRect {
        CGRect(
            x: bounds.maxX - Self.trailing - Self.trashSide,
            y: bounds.midY - Self.trashSide / 2,
            width: Self.trashSide,
            height: Self.trashSide
        )
    }

    var time: CGRect {
        CGRect(
            x: trash.minX - Self.gap - timeWidth,
            y: bounds.minY,
            width: timeWidth,
            height: bounds.height
        )
    }

    var title: CGRect {
        let start = dot.maxX + Self.gap
        let end = (timeWidth > 0 ? time.minX : trash.minX) - Self.gap
        return CGRect(x: start, y: bounds.minY, width: max(0, end - start), height: bounds.height)
    }

    /// 누르는 자리는 그림보다 넉넉하다 — 게으른 손은 조준하지 않는다.
    func hitsTrash(_ point: CGPoint) -> Bool {
        trash.insetBy(dx: -4, dy: -3).contains(point)
    }
}

// 시간 한 조각(`MemoTimeLabel`)은 폰과 나누려고 LazyMemoCore 로 올렸다.

// MARK: - 줄 그리기

/// 메뉴 안의 메모 한 줄 — 직접 그린다.
///
/// **왜 시스템 메뉴 항목이 아닌가.** 글자 하나에 동작 하나뿐인 항목으로는
/// "지우기" 를 둘 자리가 없다. 그래서 지우려면 바탕화면에서 그 종이를 찾아
/// 오른쪽 버튼을 누르고 시스템 편집 메뉴 맨 아래까지 내려가야 했다 —
/// 자주 하는 일 중 가장 먼 길이었고, 목록에서 지울 길은 아예 없었다.
///
/// 줄 하나에 셋을 담는다. 왼쪽에 종이 색(찬 점 = 바탕화면에 있음, 빈 점 =
/// 치워 둔 것), 가운데에 제목, 오른쪽에 시간과 휴지통. 휴지통은 평소 거의
/// 보이지 않다가 포인터가 그 줄에 오면 또렷해진다 (철학 4). **다만 아주
/// 사라지지는 않는다** — 숨겨 두면 있는 줄을 모르고, 모르면 없는 것과 같다.
@MainActor
final class MemoRow: NSView {
    private static let titleFont = NSFont.systemFont(ofSize: 13)
    /// 시간 한 조각의 글꼴 — **숫자만 등폭이다** (`Theme.micro` 와 같은 셈).
    ///
    /// 이 목록에서는 줄이 세로로 서고 시간은 오른쪽에 붙는다. 비례 숫자는
    /// `1` 이 좁아서 「오늘 11:00」과 「오늘 9:30」의 오른쪽 끝이 서로 어긋나는데,
    /// 이 줄을 직접 그리기로 한 까닭 중 하나가 시스템 목록의 들쭉날쭉함이었다
    /// (§14.10). 여기서 다시 흔들리면 그 결정이 반만 지켜진다.
    ///
    /// 폭을 재는 자리(`geometry`)도 같은 글꼴을 쓰므로 셈은 함께 움직인다.
    private static let timeFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    /// 포인터가 없을 때의 휴지통 세기. 있는 줄만 알 만큼.
    private static let restingTrash: CGFloat = 0.24

    /// 골라진 줄의 바탕 세기. 빠른 입력의 골라진 줄과 **같은 값**이다.
    private static let highlightWash: CGFloat = 0.20

    private let titleText: String
    private let timeText: String
    private let color: MemoColor
    private let dotColor: NSColor
    private let onDesktop: Bool
    private let geometry: MemoRowGeometry
    private let onOpen: () -> Void
    private let onDelete: () -> Void

    private var isOverTrash = false

    /// 화면 밖 렌더에서만 쓴다 (설계문서 §14.9). 메뉴 밖에는
    /// `enclosingMenuItem` 이 없어 강조도 휴지통도 연출할 방법이 없고,
    /// 그러면 이 줄의 새로운 점이 그림에 하나도 안 나타난다.
    var staged: (highlighted: Bool, overTrash: Bool)?

    init(
        title: String,
        time: String,
        color: MemoColor,
        onDesktop: Bool,
        onOpen: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.titleText = title
        self.timeText = time
        self.color = color
        self.dotColor = NSColor(color.tint)
        self.onDesktop = onDesktop
        self.onOpen = onOpen
        self.onDelete = onDelete
        self.geometry = MemoRowGeometry(
            timeWidth: time.isEmpty
                ? 0
                : ceil((time as NSString).size(withAttributes: [.font: Self.timeFont]).width)
        )
        super.init(frame: geometry.bounds)
        setAccessibilityLabel("\(title), \(time)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("코드로만 만든다") }

    // MARK: 그리기

    private var isHighlighted: Bool {
        staged?.highlighted ?? enclosingMenuItem?.isHighlighted ?? false
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHighlighted
        if let staged { isOverTrash = staged.overTrash }
        if highlighted {
            Self.highlightFill(color).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
        }

        // **글자 색은 강조와 함께 뒤집히지 않는다.** 종이색 바탕은 옅어서
        // 잉크가 그대로 읽히고, 뒤집으면 여덟 줄 중 한 줄만 다른 재질이 된다.
        let primary = NSColor.labelColor
        let secondary = NSColor.secondaryLabelColor

        drawDot()
        draw(titleText, in: geometry.title, font: Self.titleFont, color: primary, alignment: .left)
        if !timeText.isEmpty {
            draw(timeText, in: geometry.time, font: Self.timeFont, color: secondary, alignment: .right)
        }
        drawTrash(highlighted: highlighted, primary: primary)
    }

    /// 골라진 줄의 바탕 — **그 메모의 종이색이다.**
    ///
    /// 시스템 파랑(`selectedContentBackgroundColor`)을 썼었다. 그것은 이 목록만
    /// 다른 앱에서 잘라 온 부품처럼 보이게 했고, 무엇보다 같은 메모를 두 곳에서
    /// 다르게 그렸다 — 빠른 입력의 골라진 줄은 그 메모의 종이색이 옅게 깔린다
    /// (§14.10 — 두 곳에서 같은 메모를 다르게 그리면 사람은 그것을 두 개의
    /// 목록으로 배운다). 여기서도 같은 낱말을 쓴다.
    ///
    /// 뷰 밖에서 계산할 수 있게 열어 둔다: 색이 시스템 강조색으로 되돌아간
    /// 것은 그림을 봐서는 "파란색이네" 까지밖에 말할 수 없다 (`MemoRowTests`).
    static func highlightFill(_ color: MemoColor) -> NSColor {
        NSColor(color.tint).withAlphaComponent(highlightWash)
    }

    /// 찬 점은 바탕화면에 나와 있는 종이, 빈 점은 치워 둔 종이.
    ///
    /// 예전에는 체크 표시를 썼는데, 체크는 "다 한 일" 로 읽힌다 — 메모 앱에서
    /// 그건 정반대의 뜻이다.
    private func drawDot() {
        let dot = geometry.dot
        if onDesktop {
            dotColor.setFill()
            NSBezierPath(ovalIn: dot).fill()
        } else {
            dotColor.withAlphaComponent(0.8).setStroke()
            let ring = NSBezierPath(ovalIn: dot.insetBy(dx: 0.75, dy: 0.75))
            ring.lineWidth = 1.5
            ring.stroke()
        }
    }

    private func drawTrash(highlighted: Bool, primary: NSColor) {
        let box = geometry.trash

        if isOverTrash {
            // 지우기는 되돌릴 수 있지만 되돌리는 것도 조작이다. 누르기 직전에
            // "이건 다른 종류의 버튼" 이라고 한 번 말해 준다.
            NSColor.systemRed.withAlphaComponent(0.92).setFill()
            NSBezierPath(ovalIn: box.insetBy(dx: 1, dy: 1)).fill()
        }

        let tint: NSColor = isOverTrash
            ? .white
            : primary.withAlphaComponent(highlighted ? 0.8 : Self.restingTrash)
        guard let image = Self.trashImage(tint) else { return }
        let size = image.size
        image.draw(in: CGRect(
            x: box.midX - size.width / 2,
            y: box.midY - size.height / 2,
            width: size.width,
            height: size.height
        ))
    }

    private static func trashImage(_ color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: "trash", accessibilityDescription: "지우기")?
            .withSymbolConfiguration(configuration)
    }

    private func draw(
        _ text: String, in rect: CGRect, font: NSFont, color: NSColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment

        let height = ceil(font.ascender - font.descender)
        let line = CGRect(
            x: rect.minX,
            y: rect.midY - height / 2 + font.descender / 2,
            width: rect.width,
            height: height
        )
        (text as NSString).draw(
            in: line,
            withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
    }

    // MARK: 포인터

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { needsDisplay = true }

    override func mouseMoved(with event: NSEvent) {
        let over = geometry.hitsTrash(convert(event.locationInWindow, from: nil))
        guard over != isOverTrash else { return }
        isOverTrash = over
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isOverTrash = false
        needsDisplay = true
    }

    // MARK: 누르기

    override func mouseDown(with event: NSEvent) {
        isOverTrash = geometry.hitsTrash(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let deleting = geometry.hitsTrash(convert(event.locationInWindow, from: nil))
        enclosingMenuItem?.menu?.cancelTracking()
        // 메뉴가 닫히는 도중에 창을 열거나 파일을 옮기면 자리 계산과 포커스가
        // 어긋난다. 메뉴가 사라진 뒤로 한 박자 미룬다.
        let action = deleting ? onDelete : onOpen
        Task { @MainActor in action() }
    }
}
