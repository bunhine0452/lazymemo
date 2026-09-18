import SwiftUI

/// 손으로 그린 동그라미 — 달력의 「오늘」.
///
/// 맥 달력의 `PenMarks.HandRing` 과 같은 몸짓을 위젯 크기로 줄인 것이다 (설계문서 §10.3 —
/// 「낱말을 부품에서 펜 자국으로」). 채운 원은 어느 앱에나 있는 표시이고, 채우면 그 위의
/// 숫자가 종이를 떠난다. 여기서는 숫자가 종이에 그대로 남고 동그라미만 둘러진다.
///
/// 두 가지를 지킨다. **닫지 않는다** — 한 바퀴를 조금 넘겨 나가며 가늘어지는 꼬리가 이
/// 표시의 전부다; 정확히 닫히면 그것은 손이 아니라 도형이다. **굵기가 일정하지 않다** —
/// 자로 그은 선은 손으로 읽히지 않는다. 세 도막으로 나눠 굵기를 줄이며 긋는다.
///
/// 난수를 쓰지 않는다. 격자 한 칸에 한 번 그리는 자국이라 흔들림은 상수로 못 박아 두는
/// 편이 싸고(장면마다 같은 그림), `Canvas` 하나가 곧 레이어 하나다 (설계문서 §14.8).
struct HandRing: View {
    var color: Color
    var line: CGFloat = 1.7

    /// 한 바퀴를 넘겨 그은 만큼 (라디안). 많이 넘기면 꼬리가 획을 가로질러 낙서가 된다.
    private static let overshoot: CGFloat = 0.28
    /// 오른손이 동그라미를 시작하는 자리 — 왼쪽 위.
    private static let begin: CGFloat = -0.85 * .pi
    private static let samples = 48

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard size.width > line * 2, size.height > line * 2 else { return }
            let points = Self.trace(in: size, inset: line)
            // 세 도막 — 굵은 데서 가는 데로. 도막마다 한 점씩 겹쳐 이음매를 감춘다.
            let widths: [CGFloat] = [line, line * 0.78, line * 0.48]
            let cut = points.count / widths.count
            for (order, width) in widths.enumerated() {
                let start = order * cut
                let end = order == widths.count - 1 ? points.count : min(points.count, start + cut + 1)
                guard end - start > 1 else { continue }
                var path = Path()
                path.addLines(Array(points[start..<end]))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    /// 기울고, 눌리고, 둘레가 고르지 않은 타원 한 바퀴 남짓.
    private static func trace(in size: CGSize, inset: CGFloat) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + size.height * 0.012)
        let radiusX = (size.width - inset) / 2
        let radiusY = (size.height - inset) / 2 * 1.03
        let tilt: CGFloat = 0.14
        let span = 2 * .pi + overshoot
        return (0...samples).map { step in
            let t = begin + span * CGFloat(step) / CGFloat(samples)
            // 두 파장을 겹쳐야 「덜덜 떨림」이 아니라 「빨리 그은 것」으로 읽힌다.
            let swell = 1 + 0.022 * sin(t * 2 + 0.6) + 0.011 * sin(t * 5 - 1.1)
            let x = cos(t) * radiusX * swell
            let y = sin(t) * radiusY * swell
            return CGPoint(
                x: center.x + x * cos(tilt) - y * sin(tilt),
                y: center.y + x * sin(tilt) + y * cos(tilt)
            )
        }
    }
}
