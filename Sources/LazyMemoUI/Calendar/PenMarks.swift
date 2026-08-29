import LazyMemoCore
import SwiftUI

/// 「달력」의 표시들 — **부품이 아니라 펜 자국.**
///
/// 앞선 판의 달력은 채운 원·테두리 원·캡슐 점으로 말했다. 전부 맞는 표시였고,
/// 전부 **어느 앱에나 있는 표시**였다. 이 앱은 재질이 하나(좋은 종이)인데
/// 그 위에 놓인 표시만 UI 부품이면 달력만 남의 물건처럼 보인다.
///
/// 그래서 달력이 쓰는 낱말을 종이 위의 몸짓으로 바꿔 적었다.
///
/// | 뜻 | 몸짓 |
/// |---|---|
/// | 오늘 | 손으로 그린 동그라미 (`HandRing`) — 한 바퀴를 살짝 넘겨 긋는다 |
/// | 고른 날 | 밑줄 (`HandUnderline`) — 종이에서 "지금 보는 것" 을 가리키는 몸짓 |
/// | 일이 많은 날 | 배어 나온 잉크 (`InkBleedLayer`) |
/// | 두 층의 경계 | 접힌 자리 (`PaperCrease`) — 선이 아니라 한 장이 접힌 것 |
/// | 다음 한 줄 | 비워 둔 줄 (`DashedRule`) — 채우라고 말하지 않는다 |
///
/// 획은 `stroke` 로 그리지 않는다. 굵기가 일정한 선은 손이 아니라 자로 읽히고,
/// 그것이 아이콘에서 흘림선을 직접 만든 이유와 같다 (설계문서 §14.7). 여기서도
/// 중심선을 따라가며 법선 방향으로 폭을 보간해 **가변 굵기 도형**을 만든다.

// MARK: - 오늘

/// 손으로 그린 동그라미.
///
/// 정확히 닫히면 그것은 손이 아니라 도형이다. 시작점보다 조금 더 돌아 나가며
/// 가늘어지는 꼬리가 이 표시의 전부다.
struct HandRing: Shape {
    var seed: UInt64
    var startWidth: CGFloat = 1.8
    var endWidth: CGFloat = 0.7
    /// 한 바퀴를 넘겨 그은 만큼 (라디안).
    ///
    /// 처음엔 크게 잡았다가 줄였다. 많이 넘기면 꼬리가 획을 가로질러 `e` 처럼
    /// 읽힌다 — 그건 동그라미가 아니라 낙서다. **한 번에 그은 것으로 보이되
    /// 닫히지만 않으면** 충분하다.
    var overshoot: CGFloat = 0.26
    var samples: Int = 72

    nonisolated func path(in rect: CGRect) -> Path {
        guard rect.width > startWidth, rect.height > startWidth, samples > 1 else { return Path() }

        var hand = PenHand(seed: seed)
        // 사람이 그린 동그라미는 정원이 아니다 — 기울고, 눌리고, 가운데가 밀린다.
        let tilt = hand.jitter(0.16)
        let squash = 1 + hand.jitter(0.04)
        let driftX = hand.jitter(rect.width * 0.02)
        let driftY = hand.jitter(rect.height * 0.02)
        // 둘레가 고르지 않은 정도. 두 파장을 겹쳐야 "덜덜 떨림" 이 아니라
        // "빨리 그은 것" 으로 읽힌다. 진폭은 아주 작아야 한다 — 손이 흔들린
        // 티가 나기 시작하면 표시가 아니라 잡티가 된다.
        let swellA = hand.jitter(0.022)
        let swellB = hand.jitter(0.012)
        let phase = hand.next() * 2 * .pi
        // 오른손이 동그라미를 시작하는 자리 — 왼쪽 위.
        let begin = -0.85 * .pi + hand.jitter(0.18)

        let center = CGPoint(x: rect.midX + driftX, y: rect.midY + driftY)
        let radiusX = (rect.width - startWidth) / 2
        let radiusY = (rect.height - startWidth) / 2 * squash
        let span = 2 * .pi + overshoot
        let cosTilt = cos(tilt), sinTilt = sin(tilt)

        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        outer.reserveCapacity(samples + 1)
        inner.reserveCapacity(samples + 1)

        for step in 0...samples {
            let progress = CGFloat(step) / CGFloat(samples)
            let angle = begin + span * progress
            let swell = 1 + swellA * sin(3 * angle + phase) + swellB * sin(5 * angle - phase)
            let rx = radiusX * swell, ry = radiusY * swell

            let localX = cos(angle) * rx, localY = sin(angle) * ry
            let point = CGPoint(
                x: center.x + localX * cosTilt - localY * sinTilt,
                y: center.y + localX * sinTilt + localY * cosTilt
            )
            // 접선을 기울인 뒤 90도 돌리면 폭을 벌릴 방향이 나온다.
            let dx = -sin(angle) * rx, dy = cos(angle) * ry
            let tangentX = dx * cosTilt - dy * sinTilt
            let tangentY = dx * sinTilt + dy * cosTilt
            let length = max(sqrt(tangentX * tangentX + tangentY * tangentY), 0.0001)
            let normalX = -tangentY / length, normalY = tangentX / length

            // 끝으로 갈수록 빠르게 가늘어져야 꼬리가 "흐지부지" 로 읽힌다.
            let half = (startWidth + (endWidth - startWidth) * CGFloat(pow(Double(progress), 0.85))) / 2
            outer.append(CGPoint(x: point.x + normalX * half, y: point.y + normalY * half))
            inner.append(CGPoint(x: point.x - normalX * half, y: point.y - normalY * half))
        }

        return closedBand(outer: outer, inner: inner)
    }
}

// MARK: - 고른 날

/// 밑줄. 종이에서 "지금 이걸 보고 있다" 를 말하는 가장 오래된 몸짓이다.
///
/// 원으로 감싸지 않는 이유는 오늘의 동그라미와 겹치기 때문이다. 오늘이면서
/// 고른 날일 때 — 창을 열면 늘 그렇다 — 두 표시가 함께 보여야 한다.
struct HandUnderline: Shape {
    var seed: UInt64
    var startWidth: CGFloat = 1.7
    var endWidth: CGFloat = 0.5
    var samples: Int = 40

    nonisolated func path(in rect: CGRect) -> Path {
        guard rect.width > 1, samples > 1 else { return Path() }

        var hand = PenHand(seed: seed &* 31 &+ 7)
        // 손으로 그은 밑줄은 오른쪽으로 갈수록 살짝 들리고 가운데가 처진다.
        let lift = rect.height * (0.34 + hand.jitter(0.16))
        let sag = rect.height * (0.30 + hand.jitter(0.12))
        let start = CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.16)
        let end = CGPoint(x: rect.maxX, y: rect.midY - lift)
        let control = CGPoint(x: rect.midX + hand.jitter(rect.width * 0.1), y: rect.midY + sag)

        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        upper.reserveCapacity(samples + 1)
        lower.reserveCapacity(samples + 1)

        for step in 0...samples {
            let t = CGFloat(step) / CGFloat(samples)
            let u = 1 - t
            let point = CGPoint(
                x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
            )
            let dx = 2 * u * (control.x - start.x) + 2 * t * (end.x - control.x)
            let dy = 2 * u * (control.y - start.y) + 2 * t * (end.y - control.y)
            let length = max(sqrt(dx * dx + dy * dy), 0.0001)
            let normalX = -dy / length, normalY = dx / length

            let half = (startWidth + (endWidth - startWidth) * CGFloat(pow(Double(t), 0.9))) / 2
            upper.append(CGPoint(x: point.x + normalX * half, y: point.y + normalY * half))
            lower.append(CGPoint(x: point.x - normalX * half, y: point.y - normalY * half))
        }

        return closedBand(outer: upper, inner: lower)
    }
}

/// 위·아래 두 줄의 점을 하나의 닫힌 도형으로 잇는다. 가변 굵기 획은 결국
/// 이것뿐이다 — 중심선의 양옆을 따라 걸어갔다 돌아온다.
private func closedBand(outer: [CGPoint], inner: [CGPoint]) -> Path {
    guard let first = outer.first else { return Path() }
    var path = Path()
    path.move(to: first)
    for point in outer.dropFirst() { path.addLine(to: point) }
    for point in inner.reversed() { path.addLine(to: point) }
    path.closeSubpath()
    return path
}

// MARK: - 번진 잉크

/// 붐비는 날의 얼룩을 **한 장에 몰아 그린다.**
///
/// 칸마다 도형을 두면 42칸 × 최대 셋이라 화면에 뷰가 백 개 넘게 생긴다
/// (설계문서 §14.8 — 레이어 수가 곧 메모리 예산). 격자는 균일하므로 얼룩의
/// 자리도 산수로 나오고, 그러면 `Canvas` 하나로 달 전체가 끝난다. 앞선 판의
/// 캡슐 점보다 **오히려 가볍다.**
///
/// 같은 장에 **이번 주**도 함께 긋는다 (`week`). 획이 하나 더 늘어도 레이어는
/// 그대로이고, 무엇보다 얼룩과 같은 산수(칸 크기)를 쓴다 — 따로 그리면 둘이
/// 반 칸씩 어긋난 것을 그림에서 알아채지 못한다.
///
/// 얼룩은 숫자 **아래**에 앉는다. 처음엔 칸 한가운데에 두었는데, 그러면 숫자가
/// 잿빛 원판 위에 올라앉아 "고른 칸" 으로 읽혔다 — 여러 색이 섞이면 얼룩은
/// 어차피 잿빛이 되므로 그것은 색이 아니라 **부품**으로 보인다. 내려놓으니
/// 숫자는 종이 위에 그대로 남고, 얼룩은 종이결을 따라 번진 자국이 된다.
struct InkBleedLayer: View {
    struct Stain: Equatable {
        /// 격자에서 몇 번째 칸인가.
        let index: Int
        /// 그 날 메모의 색. 앞의 셋만.
        let inks: [Color]
        let count: Int
        /// 지난 날이면 얼룩도 함께 마른다 (철학 3).
        let presence: Double
    }

    let rows: Int
    let stains: [Stain]
    /// 오늘이 든 주. 다른 달로 넘어가 있으면 `nil`.
    var week: Int?

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard rows > 0, size.width > 0, size.height > 0 else { return }
            let cell = CGSize(
                width: size.width / CGFloat(MonthGridGeometry.columns),
                height: size.height / CGFloat(rows)
            )

            if let week, week >= 0, week < rows {
                sweep(&context, size: size, cell: cell, row: week)
            }

            for stain in stains {
                let column = stain.index % MonthGridGeometry.columns
                let row = stain.index / MonthGridGeometry.columns
                guard row < rows else { continue }

                var hand = PenHand(seed: UInt64(stain.index) &+ 977)
                let spread = InkBleed.spread(count: stain.count)
                let radius = InkBleed.radius(cell: cell, spread: spread)
                let center = CGPoint(
                    x: (CGFloat(column) + 0.5) * cell.width,
                    y: (CGFloat(row) + 0.5) * cell.height + cell.height * InkBleed.drop
                )
                // 색이 여럿이면 옆으로 늘어놓는다. 겹쳐 찍으면 섞여서 잿빛이
                // 되고, 그러면 "그 파란 거" 를 자리로 기억할 수 없다.
                let step = cell.width * 0.095
                let lead = -step * CGFloat(stain.inks.count - 1) / 2

                for (order, ink) in stain.inks.enumerated() {
                    let spot = CGPoint(
                        x: center.x + lead + step * CGFloat(order) + hand.jitter(cell.width * 0.03),
                        y: center.y + hand.jitter(cell.height * 0.035)
                    )
                    let reach = radius * (1 - CGFloat(order) * 0.10)
                    let alpha = InkBleed.alpha(spread: spread, order: order) * stain.presence

                    // 종이결을 따라 옆으로 번진다 — 둥근 얼룩은 다시 점이 된다.
                    var wick = context
                    wick.translateBy(x: spot.x, y: spot.y)
                    wick.scaleBy(x: 1, y: InkBleed.squash)
                    wick.fill(
                        Path(ellipseIn: CGRect(
                            x: -reach, y: -reach, width: reach * 2, height: reach * 2
                        )),
                        with: .radialGradient(
                            Gradient(stops: [
                                .init(color: ink.opacity(alpha), location: 0),
                                .init(color: ink.opacity(alpha * 0.62), location: 0.5),
                                .init(color: ink.opacity(0), location: 1),
                            ]),
                            center: .zero, startRadius: 0, endRadius: reach
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// **이번 주** — 형광펜으로 한 번 슥 그은 자국.
    ///
    /// 오늘은 동그라미가 이미 가리키지만, 게으른 사람이 달력에서 실제로 보는
    /// 단위는 하루가 아니라 **이번 주**다 ("이번 주에 뭐 있더라"). 그런데 앞선
    /// 판에는 주를 말하는 표시가 하나도 없어서, 오늘 칸 하나를 찾은 다음 그
    /// 줄을 눈으로 다시 훑어야 했다.
    ///
    /// 자국이지 칸이 아니다. 양 끝은 종이에 닿기 전에 흐려지고(형광펜은 칸에
    /// 맞춰 멈추지 않는다) 세기는 알아챌 수 있는 최소치다 — 진해지는 순간
    /// 그것은 자국이 아니라 **골라 놓은 줄**로 읽히고, 고르는 일은 밑줄이
    /// 이미 하고 있다.
    private func sweep(_ context: inout GraphicsContext, size: CGSize, cell: CGSize, row: Int) {
        let wash = Theme.highlightWash.opacity(0.30)
        let band = CGRect(
            x: 0, y: CGFloat(row) * cell.height + cell.height * 0.14,
            width: size.width, height: cell.height * 0.72
        )
        context.fill(
            Path(roundedRect: band, cornerRadius: band.height * 0.28),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: wash.opacity(0), location: 0),
                    .init(color: wash, location: 0.10),
                    .init(color: wash, location: 0.90),
                    .init(color: wash.opacity(0), location: 1),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)
            )
        )
    }
}

// MARK: - 접힌 자리

/// 조망과 조작 사이 — **선이 아니라 종이가 접힌 자리다.**
///
/// 1px 실선을 그으면 두 면이 두 개의 판으로 갈라진다. 그런데 이 창의 요지는
/// 두 층이 **한 장에** 있다는 것이다 (설계문서 §10.2). 접힌 자국은 가르면서도
/// 한 장임을 말한다.
///
/// 자국 하나가 접힌 선을 넘어간다 — 고른 날을 가리키는 표시다. 아래(또는
/// 옆) 목록이 격자의 어느 칸에서 나온 것인지 날짜를 되읽지 않고 알 수 있다.
///
/// **접는 방향은 판형이 정한다** (`CalendarLayout`). 세로로 선 창에서는
/// 가로로 접히고, 가로로 누운 창에서는 세로로 선다 — 종이를 반으로 접을 때
/// 긴 쪽을 따라 접는 것과 같다. 접히는 방향이 달라져도 그늘·선·빛의 순서는
/// 그대로다. 그 셋의 순서가 곧 "접혔다" 는 뜻이기 때문이다.
struct PaperCrease: View {
    enum Axis: Equatable {
        /// 가로로 접힌다 — 위는 그늘, 아래는 빛.
        case horizontal
        /// 세로로 접힌다 — 왼쪽은 그늘, 오른쪽은 빛.
        case vertical
    }

    var axis: Axis = .horizontal
    /// 가리킬 자리 — 가로 접힘이면 x, 세로 접힘이면 y (이 뷰의 지역 좌표).
    /// 격자를 아직 재지 못했으면 `nil`.
    var pointer: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    /// 접힌 선이 앉는 깊이. 그 앞은 그늘, 그 뒤는 빛.
    private static let crease: CGFloat = 6
    static let thickness: CGFloat = 13

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let ink = Paper.ink
            let span = axis == .horizontal ? size.width : size.height
            // 접히며 생긴 그늘 — 접힌 선으로 갈수록 짙다.
            context.fill(
                band(from: 0, to: Self.crease, in: size),
                with: .linearGradient(
                    Gradient(colors: [ink.opacity(0), ink.opacity(0.075)]),
                    startPoint: .zero,
                    endPoint: axis == .horizontal
                        ? CGPoint(x: 0, y: Self.crease) : CGPoint(x: Self.crease, y: 0)
                )
            )
            // 접힌 선.
            context.fill(
                band(from: Self.crease, to: Self.crease + 0.75, in: size),
                with: .color(ink.opacity(0.16))
            )
            // 넘어간 면이 받는 빛. 이것이 있어야 접힌 것으로 보인다.
            context.fill(
                band(from: Self.crease + 0.75, to: Self.crease + 1.5, in: size),
                with: .color(Color.white.opacity(colorScheme == .dark ? 0.045 : 0.5))
            )

            if let pointer, pointer > 0, pointer < span {
                context.fill(pointerMark(at: pointer), with: .color(ink.opacity(0.30)))
            }
        }
        .frame(
            width: axis == .vertical ? Self.thickness : nil,
            height: axis == .horizontal ? Self.thickness : nil
        )
        .allowsHitTesting(false)
    }

    /// 접힌 선을 가로지르는 띠. 방향만 다르고 깊이는 같다.
    private func band(from: CGFloat, to: CGFloat, in size: CGSize) -> Path {
        axis == .horizontal
            ? Path(CGRect(x: 0, y: from, width: size.width, height: to - from))
            : Path(CGRect(x: from, y: 0, width: to - from, height: size.height))
    }

    /// 접힌 선을 넘어 내려긋는(또는 그어 나가는) 짧은 획. 끝이 가늘어지는
    /// 것은 이 앱의 다른 획들과 같다.
    private func pointerMark(at position: CGFloat) -> Path {
        let near = Self.crease + 1
        let far = Self.thickness - 1.5
        var path = Path()
        if axis == .horizontal {
            path.move(to: CGPoint(x: position - 1.1, y: near))
            path.addLine(to: CGPoint(x: position + 1.1, y: near))
            path.addLine(to: CGPoint(x: position + 0.25, y: far))
            path.addLine(to: CGPoint(x: position - 0.25, y: far))
        } else {
            path.move(to: CGPoint(x: near, y: position - 1.1))
            path.addLine(to: CGPoint(x: near, y: position + 1.1))
            path.addLine(to: CGPoint(x: far, y: position + 0.25))
            path.addLine(to: CGPoint(x: far, y: position - 0.25))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 비워 둔 줄

/// 다음 한 줄이 그어져 있다. **채우라고 말하지 않고 자리만 비워 둔다** (철학 1).
struct DashedRule: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
