// lazymemo 아이콘을 코드로 그린다.
//
// 디자인 파일 대신 코드로 두는 이유: 저장소에 출처를 알 수 없는 바이너리를
// 넣지 않고, 색·비례를 고치는 일이 diff 로 남으며, 누구나 재현할 수 있다.
//
//   swift scripts/make-icon.swift            # .iconset + 메뉴바 템플릿
//   swift scripts/make-icon.swift --sheet    # 시스템이 깎은 모습으로 미리보기
//   swift scripts/make-icon.swift --texture  # 종이 결
//   swift scripts/make-icon.swift --ios      # 아이폰 앱의 1024 (알파 없음)
//
// 크림과 포레스트 리브랜딩. 기존 두 글줄 실루엣을 유지하고 색과 명암을 정리한다.
// macOS 26의 시스템 마스크가 실루엣을 만들므로 캔버스를 끝까지 채운다.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 캔버스

/// 아이콘이 놓이는 자리. 값은 전부 이 기기에서 잰 것이다 (위 주석).
enum IconCanvas {
    static let side: CGFloat = 1024
    /// 우리가 그리는 면. **끝까지 채운다.**
    static let full = CGRect(x: 0, y: 0, width: side, height: side)
    /// 시스템이 남기는 몸통. 이 밖은 잘려 나간다.
    static let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    /// 몸통 모서리의 초타원 지수. 마스크 실루엣에 최소제곱으로 맞춘 값(RMS 4.1px).
    static let maskExponent: Double = 4.47
    /// 모서리 곡률에 물리지 않는 안쪽. 획은 여기 안에 둔다.
    static var safe: CGRect { body.insetBy(dx: 92, dy: 92) }
}

// MARK: - 팔레트

/// 아이콘의 색. **재질은 하나 — 좋은 종이다** (§14.5).
///
/// 앞선 판에는 슬레이트 네이비 판과 황동 클립이 더 있었다. 둘 다 «그릇» 의
/// 색이었고, 시스템이 그릇을 대주기 시작하면서 갈 자리가 없어졌다.
enum Palette {
    /// 300g 웜 코튼 페이퍼. 위에서 빛이 들어 아래로 갈수록 가라앉는다.
    ///
    /// 앞선 판보다 **한 단 더 익혔다.** 판 위에 작게 얹혀 있을 때는 흰 종이가
    /// 맞았지만, 이제 종이가 아이콘 전부라서 그대로 두면 Finder 사이드바나
    /// 밝은 Dock 위에서 «흰 네모» 로 녹아 없어진다. 크림 쪽으로 당겨 두면
    /// 밝은 바탕에서도 종이의 윤곽이 남는다.
    static let paperTop = CGColor(red: 0.23, green: 0.42, blue: 0.35, alpha: 1)
    static let paperBottom = CGColor(red: 0.12, green: 0.25, blue: 0.21, alpha: 1)

    /// 가장자리로 갈수록 앉는 그늘. 평평한 면을 **덩어리**로 만든다.
    static let edgeShade = CGColor(red: 0.02, green: 0.08, blue: 0.05, alpha: 0.16)
    /// 가장자리에 서는 얇은 빛 — 종이의 잘린 단면.
    static let edgeLight = CGColor(red: 1, green: 1, blue: 1, alpha: 0.10)
    /// 위쪽에서 드는 빛.
    static let topLight = CGColor(red: 1, green: 1, blue: 1, alpha: 0.08)

    /// 딥 프러시안 만년필 잉크 & 웜 앰버 하이라이트
    static let deepInk = CGColor(red: 0.98, green: 0.96, blue: 0.88, alpha: 1)
    static let amberInk = CGColor(red: 0.70, green: 0.84, blue: 0.60, alpha: 1)
    static let subtleDot = CGColor(red: 0.31, green: 0.26, blue: 0.18, alpha: 0.02)
}

// MARK: - 도형

/// 애플식 연속 곡률 모서리에 가까운 초타원.
func squirclePath(in rect: CGRect, exponent: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let halfWidth = rect.width / 2
    let halfHeight = rect.height / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let steps = 720

    for step in 0...steps {
        let angle = Double(step) / Double(steps) * 2 * .pi
        let cosine = cos(angle), sine = sin(angle)
        let x = halfWidth * copysign(pow(abs(cosine), 2 / exponent), cosine)
        let y = halfHeight * copysign(pow(abs(sine), 2 / exponent), sine)
        let point = CGPoint(x: center.x + x, y: center.y + y)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// 종이 카드. `fold` 를 주면 오른쪽 아래 모서리가 접힌다.
func notePath(in rect: CGRect, cornerRadius radius: CGFloat, fold: CGFloat = 0) -> CGPath {
    let path = CGMutablePath()

    path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
    path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)

    if fold > 0 {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
    } else {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY), radius: radius)
    }

    path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius), radius: radius)
    path.closeSubpath()
    return path
}

/// 첫 줄 — **반듯하게 쓴** 만년필 글줄.
///
/// 카드 위가 아니라 몸통(`IconCanvas.body`) 기준이다. 좌우 0.18 을 비우는데,
/// 이보다 넓히면 획 끝이 초타원 모서리가 휘어 들어오는 구간에 닿는다.
func firstLinePath(in card: CGRect) -> CGPath {
    let path = CGMutablePath()
    let insetX = card.width * 0.165
    let y = card.minY + card.height * 0.365
    path.move(to: CGPoint(x: card.minX + insetX, y: y))
    path.addLine(to: CGPoint(x: card.maxX - insetX, y: y))
    return path
}

/// 굵기가 변하는 테이퍼드 획.
func taperedStroke(
    from start: CGPoint, to end: CGPoint,
    control1: CGPoint, control2: CGPoint,
    startWidth: CGFloat, endWidth: CGFloat,
    samples: Int = 96
) -> CGPath {
    func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*start.x + 3*u*u*t*control1.x + 3*u*t*t*control2.x + t*t*t*end.x
        let y = u*u*u*start.y + 3*u*u*t*control1.y + 3*u*t*t*control2.y + t*t*t*end.y
        return CGPoint(x: x, y: y)
    }
    func normal(_ t: CGFloat) -> CGVector {
        let u = 1 - t
        let dx = 3*u*u*(control1.x - start.x) + 6*u*t*(control2.x - control1.x) + 3*t*t*(end.x - control2.x)
        let dy = 3*u*u*(control1.y - start.y) + 6*u*t*(control2.y - control1.y) + 3*t*t*(end.y - control2.y)
        let length = max(sqrt(dx*dx + dy*dy), 0.0001)
        return CGVector(dx: -dy / length, dy: dx / length)
    }

    var upper: [CGPoint] = []
    var lower: [CGPoint] = []
    for step in 0...samples {
        let t = CGFloat(step) / CGFloat(samples)
        let center = point(t)
        let unit = normal(t)
        let half = (startWidth + (endWidth - startWidth) * pow(t, 0.75)) / 2
        upper.append(CGPoint(x: center.x + unit.dx * half, y: center.y + unit.dy * half))
        lower.append(CGPoint(x: center.x - unit.dx * half, y: center.y - unit.dy * half))
    }

    let path = CGMutablePath()
    path.move(to: upper[0])
    for candidate in upper.dropFirst() { path.addLine(to: candidate) }
    for candidate in lower.reversed() { path.addLine(to: candidate) }
    path.closeSubpath()
    return path
}

func strokeCap(at point: CGPoint, width: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(
        x: point.x - width / 2, y: point.y - width / 2, width: width, height: width
    ), transform: nil)
}

func trailingLineStart(in card: CGRect) -> CGPoint {
    CGPoint(x: card.minX + card.width * 0.165, y: card.minY + card.height * 0.585)
}

/// 둘째 줄 — **끝으로 갈수록 가늘어지며 흘러내린다.**
///
/// §14.7 이 기각한 안 셋 중 하나가 「굵기가 일정한 흘림선」이었다. 굵기가
/// 같으면 갈고리(✓)나 물결(~)로 읽히고, 그러면 «쓰다 말았다» 가 아니라
/// «표시했다» 가 된다. 그래서 stroke 가 아니라 **직접 만든 가변 굵기 도형**이다.
func trailingLinePath(in card: CGRect, weight: CGFloat) -> CGPath {
    let start = trailingLineStart(in: card)
    return taperedStroke(
        from: start,
        to: CGPoint(x: start.x + card.width * 0.605, y: start.y + card.height * 0.14),
        control1: CGPoint(x: start.x + card.width * 0.44, y: start.y - card.height * 0.005),
        control2: CGPoint(x: start.x + card.width * 0.51, y: start.y + card.height * 0.078),
        startWidth: weight, endWidth: weight * 0.16
    )
}

func trailingLineSimplified(in card: CGRect) -> CGPath {
    let path = CGMutablePath()
    let inset = card.width * 0.18
    let left = card.minX + inset
    let y = card.minY + card.height * 0.58

    path.move(to: CGPoint(x: left, y: y))
    path.addLine(to: CGPoint(x: left + card.width * 0.46, y: y + card.height * 0.13))
    return path
}

// MARK: - 그리기

func fillVerticalGradient(_ context: CGContext, in rect: CGRect, from top: CGColor, to bottom: CGColor) {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(
        colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]
    ) else { return }
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.minY),
        end: CGPoint(x: rect.midX, y: rect.maxY),
        options: []
    )
}

/// 몸통 가장자리에 앉는 그늘 — **평평한 면을 덩어리로 만든다.**
///
/// 시스템은 실루엣과 바깥 그림자를 대주지만 **면의 음영은 주지 않는다.**
/// 그늘 없이 단색을 깔면 아이콘이 «종이» 가 아니라 «칠한 사각형» 으로 보인다.
/// 안쪽으로 던진 그림자 한 겹이면 가장자리가 살짝 말려 든 것처럼 보인다.
private func shadeEdges(_ context: CGContext) {
    let body = IconCanvas.body
    let silhouette = squirclePath(in: body, exponent: IconCanvas.maskExponent)

    context.saveGState()
    context.addPath(silhouette)
    context.clip()

    // 몸통 **바깥**을 칠하면서 그림자를 안쪽으로 던진다. 칠 자체는 클립 밖이라
    // 보이지 않고, 번진 그림자만 가장자리에 남는다 (even-odd 로 몸통을 뚫는다).
    let outside = CGMutablePath()
    outside.addRect(body.insetBy(dx: -320, dy: -320))
    outside.addPath(silhouette)

    // **얇아야 한다.** 처음에는 52 로 번지게 두었더니 갈색 테가 몸통의 4분의 1을
    // 먹으면서 아이콘이 종이가 아니라 «쿠션» 으로 보였다. 종이의 잘린 단면은
    // 두껍지 않다 — 몇 픽셀이면 «면이 여기서 끝난다» 는 말은 다 한 것이다.
    context.setShadow(offset: .zero, blur: 14, color: Palette.edgeShade)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.addPath(outside)
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    // 그 그늘 바로 안쪽에 실낱 같은 빛 하나. 단면이 빛을 받는 자리다.
    context.saveGState()
    context.addPath(silhouette)
    context.clip()
    context.addPath(squirclePath(in: body.insetBy(dx: 3, dy: 3), exponent: IconCanvas.maskExponent))
    context.addPath(silhouette)
    context.setFillColor(Palette.edgeLight)
    context.fillPath(using: .evenOdd)
    context.restoreGState()
}

/// 종이 위의 도트 그리드. **앱 안의 종이와 같은 낱말이다** (`Theme.paper`).
///
/// 캔버스를 끝까지 덮는다 — 안쪽에서 멈추면 그 멈춘 자리가 «판의 테두리» 로
/// 읽혀서, 없애려고 한 겹판이 도로 생긴다.
private func drawDotGrid(_ context: CGContext) {
    let spacing: CGFloat = 62
    let radius: CGFloat = 3.1
    let canvas = IconCanvas.full

    for x in stride(from: canvas.minX + spacing / 2, through: canvas.maxX, by: spacing) {
        for y in stride(from: canvas.minY + spacing / 2, through: canvas.maxY, by: spacing) {
            context.addEllipse(in: CGRect(
                x: x - radius, y: y - radius, width: radius * 2, height: radius * 2
            ))
        }
    }
    context.setFillColor(Palette.subtleDot)
    context.fillPath()
}

/// 잉크 두 줄 — **첫 줄은 반듯하고, 둘째 줄은 흐지부지된다.**
///
/// 아이콘이 하는 말 전부가 여기 있다 (§14.7). 그릇이 없어졌으므로 획이
/// 그만큼 커졌다 — 몸통 대비 굵기를 올려야 16px 에서도 두 줄이 두 줄로 남는다.
private func drawInk(_ context: CGContext) {
    let body = IconCanvas.body
    let weight: CGFloat = 92

    context.saveGState()
    context.setLineWidth(weight)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // 획이 종이에 **눌린 자국**. 만년필은 종이를 파고 들어간다 — 아주 옅은
    // 아래쪽 그림자 하나가 잉크를 «위에 올린 색» 이 아니라 «스민 것» 으로 만든다.
    context.setShadow(offset: CGSize(width: 0, height: 3), blur: 5,
                      color: CGColor(red: 0.20, green: 0.16, blue: 0.10, alpha: 0.20))

    context.setStrokeColor(Palette.deepInk)
    context.addPath(firstLinePath(in: body))
    context.strokePath()

    context.setFillColor(Palette.amberInk)
    context.addPath(strokeCap(at: trailingLineStart(in: body), width: weight))
    context.fillPath()
    context.addPath(trailingLinePath(in: body, weight: weight))
    context.fillPath()

    context.restoreGState()
}

/// 아이콘 한 장. **캔버스를 끝까지 채운다** — 실루엣도 그림자도 시스템 몫이다.
func drawIcon(_ context: CGContext, size: CGFloat) {
    let unit = size / IconCanvas.side
    context.saveGState()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: unit, y: -unit)

    let canvas = IconCanvas.full

    // 1. 종이 — 위에서 빛이 들고 아래로 갈수록 가라앉는다.
    fillVerticalGradient(context, in: canvas, from: Palette.paperTop, to: Palette.paperBottom)

    // 2. 위쪽 빛. 몸통 절반까지만 내려온다.
    fillVerticalGradient(
        context,
        in: CGRect(x: canvas.minX, y: canvas.minY, width: canvas.width, height: canvas.height * 0.46),
        from: Palette.topLight,
        to: CGColor(gray: 1, alpha: 0)
    )

    // 3. 도트 그리드 → 4. 가장자리 그늘 → 5. 잉크. 차례가 곧 깊이다.
    drawDotGrid(context)
    shadeEdges(context)
    drawInk(context)

    context.restoreGState()
}

/// 메뉴바용 단색 템플릿. 시스템이 색을 입히므로 알파만 의미가 있다.
func drawTemplateMark(_ context: CGContext, size: CGFloat) {
    let unit = size / 1024
    context.saveGState()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: unit, y: -unit)

    let card = CGRect(x: 168, y: 104, width: 688, height: 816)

    // 메뉴바에서는 외곽선이 옳다. 꽉 찬 검은 덩어리는 이웃 아이콘들 사이에서
    // 혼자 무거워 보인다. 테두리보다 안쪽 글줄을 가늘게 잡아야 18px 에서
    // 글자처럼 뭉치지 않는다.
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.setStrokeColor(CGColor(gray: 0, alpha: 1))

    context.setLineWidth(88)
    context.addPath(notePath(in: card, cornerRadius: 150, fold: 0))
    context.strokePath()

    context.setLineWidth(72)
    context.addPath(firstLinePath(in: card))
    context.strokePath()
    context.addPath(trailingLineSimplified(in: card))
    context.strokePath()

    context.restoreGState()
}

// MARK: - 종이 결

/// 종이 표면의 결. 아주 옅은 잡티와 가로 섬유로 이루어진다.
///
/// 매끈한 단색 면은 아무리 색을 잘 골라도 화면 위의 사각형으로 보인다.
/// 실제 종이는 빛을 고르지 않게 되받아치고, 그 불균질함이 "물건" 이라는
/// 신호를 만든다. 타일로 이어 붙일 것이므로 이음매가 생기지 않게 **위치에
/// 의존하지 않는 잡음**만 쓴다.
func renderPaperGrain(size: Int = 160, seed: UInt64 = 0x1A2B_2E3D) -> CGImage? {
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // 재현 가능한 난수. 같은 결이 매번 나와야 diff 가 의미를 갖는다.
    var state = seed
    func random() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }

    // 잡티
    for y in 0..<size {
        for x in 0..<size {
            let value = random()
            guard value > 0.55 else { continue }
            let dark = value > 0.775
            let alpha = (value - 0.55) * 0.14
            context.setFillColor(CGColor(gray: dark ? 0 : 1, alpha: alpha))
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
    }

    // 가로 섬유. 종이는 결이 한 방향으로 눕는다.
    context.setLineWidth(1)
    for _ in 0..<(size / 4) {
        let y = random() * Double(size)
        let length = 6 + random() * 28
        let x = random() * Double(size)
        context.setStrokeColor(CGColor(gray: random() > 0.5 ? 0 : 1, alpha: 0.035))
        context.move(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + length, y: y))
        context.strokePath()
    }

    return context.makeImage()
}

// MARK: - 출력

func makeContext(size: CGFloat) -> CGContext? {
    let context = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.setAllowsAntialiasing(true)
    context?.interpolationQuality = .high
    return context
}

func write(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

func renderIcon(size: CGFloat) -> CGImage? {
    guard let context = makeContext(size: size) else { return nil }
    drawIcon(context, size: size)
    return context.makeImage()
}

func renderTemplate(size: CGFloat) -> CGImage? {
    guard let context = makeContext(size: size) else { return nil }
    drawTemplateMark(context, size: size)
    return context.makeImage()
}

// MARK: - 비교 시트

/// 시스템이 깎고 그림자를 붙인 뒤의 모습. **그린 그대로를 보면 안 된다.**
///
/// macOS 26 은 우리가 넣은 그림을 그대로 쓰지 않는다 (파일 첫머리 주석).
/// 그린 것을 그대로 늘어놓고 고르면 화면에 나올 물건과 다른 것을 보고 고르게
/// 된다 — 여기서는 **몸통으로 깎고 시스템과 같은 그림자를 얹어** 그린다.
private func drawMasked(_ sheet: CGContext, _ image: CGImage, in slot: CGRect) {
    let body = CGRect(
        x: slot.minX + slot.width * (IconCanvas.body.minX / IconCanvas.side),
        y: slot.minY + slot.height * (IconCanvas.body.minY / IconCanvas.side),
        width: slot.width * (IconCanvas.body.width / IconCanvas.side),
        height: slot.height * (IconCanvas.body.height / IconCanvas.side)
    )
    let silhouette = squirclePath(in: body, exponent: IconCanvas.maskExponent)

    // 시스템 그림자 — 실측한 번짐(캔버스 1024 에서 아래로 24px 남짓)을 옮겨 온다.
    sheet.saveGState()
    sheet.setShadow(offset: CGSize(width: 0, height: -slot.height * 0.012),
                    blur: slot.height * 0.045,
                    color: CGColor(gray: 0, alpha: 0.30))
    sheet.addPath(silhouette)
    sheet.setFillColor(CGColor(gray: 0.5, alpha: 1))
    sheet.fillPath()
    sheet.restoreGState()

    sheet.saveGState()
    sheet.addPath(silhouette)
    sheet.clip()
    sheet.draw(image, in: slot)
    sheet.restoreGState()
}

/// 여러 크기를 나란히 그려 눈으로 고르게 한다. 밝은 바탕과 어두운 바탕 양쪽에서 본다.
func renderComparisonSheet() -> CGImage? {
    let sizes: [CGFloat] = [256, 128, 64, 32, 16]
    let width: CGFloat = 1180
    let height: CGFloat = 640

    guard let sheet = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // 위는 밝은 바탕, 아래는 어두운 바탕. 크림 종이가 **밝은 데서 녹지 않는지**가
    // 이 아이콘의 유일한 위험이라, 두 바탕을 나란히 두는 것이 시트의 목적이다.
    sheet.setFillColor(CGColor(gray: 0.90, alpha: 1))
    sheet.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
    sheet.setFillColor(CGColor(gray: 0.22, alpha: 1))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))

    for (band, baseY) in [(0, height - 40), (1, height / 2 - 40)] {
        _ = band
        var x: CGFloat = 30
        for size in sizes {
            guard let image = renderIcon(size: size * 3) else { continue }
            drawMasked(sheet, image, in: CGRect(x: x, y: baseY - size, width: size, height: size))
            x += size + 26
        }
    }

    // 메뉴바 템플릿은 실제 크기와 확대로, 밝은·어두운 메뉴바 양쪽에서 본다.
    for (index, gray) in [0.95, 0.16].enumerated() {
        let box = CGRect(x: 830 + CGFloat(index) * 160, y: height - 340, width: 150, height: 300)
        sheet.setFillColor(CGColor(gray: gray, alpha: 1))
        sheet.fill(box)
        for (slotIndex, glyph) in [CGFloat(18), 54, 108].enumerated() {
            guard let template = renderTemplate(size: glyph * 3) else { continue }
            let slot = CGRect(x: box.midX - glyph / 2,
                              y: box.maxY - 44 - CGFloat(slotIndex) * 84 - glyph / 2,
                              width: glyph, height: glyph)
            sheet.saveGState()
            sheet.clip(to: slot, mask: template)
            sheet.setFillColor(CGColor(gray: gray > 0.5 ? 0.08 : 0.96, alpha: 1))
            sheet.fill(slot)
            sheet.restoreGState()
        }
    }

    return sheet.makeImage()
}

// MARK: - 진입점

let arguments = CommandLine.arguments
let outputDirectory = URL(filePath: FileManager.default.currentDirectoryPath)
    .appending(path: "build/icon", directoryHint: .isDirectory)

if arguments.contains("--texture") {
    guard let grain = renderPaperGrain() else { exit(1) }
    let url = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Sources/LazyMemoUI/Resources/PaperGrain.png")
    try write(grain, to: url)
    print(url.path(percentEncoded: false))
    exit(0)
}

// 아이폰 아이콘. 같은 그림이지만 **알파 채널이 없어야 한다** — App Store 는
// 투명도가 든 iOS 아이콘을 거절한다. 캔버스를 끝까지 채우니 잃는 픽셀은 없다.
if arguments.contains("--ios") {
    guard let context = CGContext(
        data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { exit(1) }
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    drawIcon(context, size: 1024)
    guard let image = context.makeImage() else { exit(1) }
    let url = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "ios/LazyMemo/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    try write(image, to: url)
    print(url.path(percentEncoded: false))
    exit(0)
}

if arguments.contains("--sheet") {
    guard let sheet = renderComparisonSheet() else { exit(1) }
    let url = outputDirectory.appending(path: "comparison.png")
    try write(sheet, to: url)
    print(url.path(percentEncoded: false))
    exit(0)
}

// .iconset 규격: 16~512 의 1x/2x
let iconset = outputDirectory.appending(path: "AppIcon.iconset", directoryHint: .isDirectory)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        guard let image = renderIcon(size: CGFloat(base * scale)) else { continue }
        let suffix = scale == 1 ? "" : "@2x"
        try write(image, to: iconset.appending(path: "icon_\(base)x\(base)\(suffix).png"))
    }
}

// 메뉴바 템플릿. 1x/2x/3x 를 따로 두는 대신 3배 해상도 한 장을 넣고
// AppKit 이 18pt 로 줄이게 한다 — 표현을 여러 개 관리할 값어치가 없다.
if let template = renderTemplate(size: 54) {
    try write(template, to: URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Sources/LazyMemoUI/Resources/MenuBarIcon.png"))
}

print(outputDirectory.path(percentEncoded: false))
