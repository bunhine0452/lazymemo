import SwiftUI

/// 비서가 도는 동안의 **잉크** — 「AI 가 실행되고 있구나」를 종이의 말로 (맥 상자·폰 펜이 같은 것을 쓴다).
///
/// 2026-09-17 사용자: 「찾아줘 하고 기다리는데 아무것도 안 뜨다가 갑자기 팍 하고 뜬다」. 작은 바퀴 하나는
/// 기다림을 채우지 못했다. 그래서 셋을 함께 —
///
/// 1. **획**(`InkStroke`): 펜이 종이에 긋는 짧은 물결. 스스로 흐르되, 모델이 글자 조각을 낼 때마다
///    (`AssistantModel.Stage.tokens`) 한 번 더 나아간다 — 움직임이 실제 생성에 묶여 있어 거짓 진행이 아니다.
/// 2. **말**: 단계가 바뀔 때마다 바뀐다 — 「메모를 뒤지는 중」→「6장 골라 읽는 중」→「답을 적는 중」. 글자 위로
///    빛이 한 번씩 지나간다(shimmer) — 애플 인텔리전스가 생각할 때 글자에 하는 그것.
/// 3. **숨**(`ThinkingGlow`): 상자·펜의 테두리가 강조색으로 천천히 숨 쉰다 — 곁눈으로도 「돌고 있다」가 보인다
///    (Siri 의 가장자리 빛과 같은 자리, 훨씬 옅게 — 재질은 종이 하나라는 원칙 §14.5).
///
/// HIG Feedback: 「사람들이 앱의 상태를 알게 하라 — 무엇이 진행 중인지, 얼마나 걸릴지」. 「손쉬운 사용 ›
/// 동작 줄이기」가 켜져 있으면 셋 다 멈춰 선다 — 획은 그어진 채, 테두리는 은은한 채.
public struct ThinkingInkStyle: Sendable {
    public var ink: Color
    public var faded: Color
    public var accent: Color

    public init(ink: Color, faded: Color, accent: Color) {
        self.ink = ink
        self.faded = faded
        self.accent = accent
    }
}

/// 획과 말 — 한 줄. `tokens` 가 오를 때마다 획이 한 번 더 나아간다.
public struct ThinkingInk: View {
    public var label: String
    public var tokens: Int
    public var style: ThinkingInkStyle
    public var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(label: String, tokens: Int, style: ThinkingInkStyle, size: CGFloat = 12) {
        self.label = label
        self.tokens = tokens
        self.style = style
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 8) {
            InkStroke(tokens: tokens, accent: style.accent, still: reduceMotion)
                .frame(width: size * 2.4, height: size * 0.9)
            ShimmerText(label, size: size, faded: style.faded, ink: style.ink, still: reduceMotion)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: label)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// 펜이 긋는 짧은 물결. 왼쪽에서 그어 오른쪽으로 빠져나가고, 꼬리가 따라 지워진다 — 잉크가 마르듯.
/// 그리고 처음부터 다시. 한 획이 화면을 다 지나간 뒤에야 다음 획이 시작한다 — 두 토막이 동시에 보이지 않게.
struct InkStroke: View {
    var tokens: Int
    var accent: Color
    var still: Bool

    /// 한 획에 걸리는 시간. 조각 하나는 이 시간의 1/12 만큼 더 민다.
    private static let lap: Double = 2.0
    /// 꼬리는 머리보다 이만큼 뒤.
    private static let length: Double = 0.45

    var body: some View {
        if still {
            wave.trim(from: 0, to: 0.85).stroke(accent, style: strokeStyle)
        } else {
            TimelineView(.animation) { context in
                let cycle = 1 + Self.length
                let t = context.date.timeIntervalSinceReferenceDate / Self.lap + Double(tokens) / 12
                let head = (t * cycle).truncatingRemainder(dividingBy: cycle)
                Canvas { canvas, bounds in
                    let path = wave.path(in: CGRect(origin: .zero, size: bounds))
                    let from = max(0, head - Self.length), to = min(1, head)
                    guard to > from else { return }
                    canvas.stroke(path.trimmedPath(from: from, to: to), with: .color(accent), style: strokeStyle)
                    // 펜촉 — 머리에 잉크 방울 하나, 획이 끝까지 가기 전까지.
                    if head <= 1, let point = path.trimmedPath(from: max(0, to - 0.001), to: to).currentPoint {
                        let dot = CGRect(x: point.x - 1.6, y: point.y - 1.6, width: 3.2, height: 3.2)
                        canvas.fill(Path(ellipseIn: dot), with: .color(accent))
                    }
                }
            }
        }
    }

    private var strokeStyle: StrokeStyle { StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round) }

    private var wave: WaveShape { WaveShape() }
}

/// 손으로 그은 물결 — 두 마루, 한 골. 자로 잰 사인파가 아니라 조금 기운 것.
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, mid = rect.midY
        path.move(to: CGPoint(x: rect.minX + 1, y: mid + h * 0.12))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.36, y: mid - h * 0.05),
                      control1: CGPoint(x: rect.minX + w * 0.10, y: mid - h * 0.55),
                      control2: CGPoint(x: rect.minX + w * 0.26, y: mid - h * 0.55))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.66, y: mid + h * 0.02),
                      control1: CGPoint(x: rect.minX + w * 0.46, y: mid + h * 0.62),
                      control2: CGPoint(x: rect.minX + w * 0.56, y: mid + h * 0.62))
        path.addCurve(to: CGPoint(x: rect.maxX - 1, y: mid - h * 0.16),
                      control1: CGPoint(x: rect.minX + w * 0.76, y: mid - h * 0.58),
                      control2: CGPoint(x: rect.minX + w * 0.90, y: mid - h * 0.50))
        return path
    }
}

/// 글자 위로 빛이 지나간다 — 바탕은 흐린 잉크, 지나가는 띠만 진한 잉크.
struct ShimmerText: View {
    var text: String
    var size: CGFloat
    var faded: Color
    var ink: Color
    var still: Bool

    init(_ text: String, size: CGFloat, faded: Color, ink: Color, still: Bool) {
        self.text = text
        self.size = size
        self.faded = faded
        self.ink = ink
        self.still = still
    }

    private static let lap: Double = 2.6

    var body: some View {
        let label = Text(text).font(.system(size: size, weight: .medium))
        if still {
            label.foregroundStyle(faded)
        } else {
            TimelineView(.animation) { context in
                let t = (context.date.timeIntervalSinceReferenceDate / Self.lap).truncatingRemainder(dividingBy: 1)
                label
                    .foregroundStyle(faded)
                    .overlay {
                        GeometryReader { proxy in
                            let width = proxy.size.width
                            // 띠는 글자 폭의 반. 왼쪽 밖에서 들어와 오른쪽 밖으로 — 그 뒤 잠깐 쉰다.
                            let x = -width * 0.6 + (width * 1.7) * min(1, t * 1.35)
                            LinearGradient(
                                stops: [.init(color: .clear, location: 0), .init(color: ink, location: 0.5), .init(color: .clear, location: 1)],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: width * 0.5)
                            .offset(x: x)
                        }
                        .mask(label)
                    }
            }
        }
    }
}

/// 테두리가 숨 쉰다 — 상자(맥)와 펜(폰)이 생각하는 동안.
public struct ThinkingGlow: ViewModifier {
    public var active: Bool
    public var accent: Color
    public var radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let breath: Double = 2.0

    public func body(content: Content) -> some View {
        // 시계는 테두리에만 건다 — 상자의 내용(글 칸 등)이 매 프레임 다시 그려지지 않게.
        content.overlay {
            if active, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // 0.3 ↔ 0.7 사이를 천천히 — 들숨 날숨.
                    let breath = 0.5 + 0.5 * sin(t * 2 * .pi / Self.breath)
                    ring(alpha: 0.3 + 0.4 * breath, blur: 1 + 2 * breath)
                }
            } else if active {
                ring(alpha: 0.5, blur: 1.5)
            }
        }
    }

    private func ring(alpha: Double, blur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(accent.opacity(alpha), lineWidth: 1.5)
            .shadow(color: accent.opacity(alpha * 0.55), radius: 6 + blur)
            .allowsHitTesting(false)
    }
}

public extension View {
    /// 비서가 도는 동안 테두리가 강조색으로 숨 쉰다.
    func thinkingGlow(_ active: Bool, accent: Color, radius: CGFloat) -> some View {
        modifier(ThinkingGlow(active: active, accent: accent, radius: radius))
    }
}
