// lazymemo 아이콘을 코드로 그린다.
//
// 디자인 파일 대신 코드로 두는 이유: 저장소에 출처를 알 수 없는 바이너리를
// 넣지 않고, 색·비례를 고치는 일이 diff 로 남으며, 누구나 재현할 수 있다.
//
//   swift scripts/make-icon.swift --variant b --out build/icon
//   swift scripts/make-icon.swift --sheet build/icon/preview.png

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// // MARK: - 팔레트 (Pro macOS Stationery)

enum Palette {
    /// 묵직하고 차분한 슬레이트 네이비 데스크 베이스플레이트
    static let backgroundTop = CGColor(red: 0.16, green: 0.19, blue: 0.26, alpha: 1)
    static let backgroundBottom = CGColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 1)

    /// 300g 고급 웜 코튼 페이퍼
    static let paperTop = CGColor(red: 0.995, green: 0.99, blue: 0.975, alpha: 1)
    static let paperBottom = CGColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1)
    static let paperEdge = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)

    /// 딥 프러시안 만년필 잉크 & 웜 앰버 하이라이트
    static let deepInk = CGColor(red: 0.11, green: 0.15, blue: 0.22, alpha: 1)
    static let amberInk = CGColor(red: 0.88, green: 0.54, blue: 0.18, alpha: 1)
    static let subtleDot = CGColor(red: 0.11, green: 0.15, blue: 0.22, alpha: 0.12)

    /// 브라스 / 코퍼 클립 악센트
    static let brassTop = CGColor(red: 0.82, green: 0.64, blue: 0.38, alpha: 1)
    static let brassBottom = CGColor(red: 0.62, green: 0.44, blue: 0.22, alpha: 1)
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

/// 접힌 모서리에 드러나는 종이 뒷면 및 그림자.
func foldPath(in rect: CGRect, fold: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
    path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - fold + 4, y: rect.maxY - fold + 4))
    path.closeSubpath()
    return path
}

/// 첫 줄 — 반듯하게 쓴 만년필 글줄.
func firstLinePath(in card: CGRect) -> CGPath {
    let path = CGMutablePath()
    let insetX = card.width * 0.16
    let y = card.minY + card.height * 0.36
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
    CGPoint(x: card.minX + card.width * 0.16, y: card.minY + card.height * 0.56)
}

func trailingLinePath(in card: CGRect, weight: CGFloat) -> CGPath {
    let start = trailingLineStart(in: card)
    return taperedStroke(
        from: start,
        to: CGPoint(x: start.x + card.width * 0.54, y: start.y + card.height * 0.14),
        control1: CGPoint(x: start.x + card.width * 0.40, y: start.y),
        control2: CGPoint(x: start.x + card.width * 0.46, y: start.y + card.height * 0.08),
        startWidth: weight, endWidth: weight * 0.12
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

enum Variant: String {
    case tilted = "a"
    case upright = "b"
}

func drawIcon(_ context: CGContext, size: CGFloat, variant: Variant) {
    let unit = size / 1024
    context.saveGState()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: unit, y: -unit)

    // macOS 베이스플레이트 규격 (824x824)
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)

    // 1. 베이스플레이트 본체 및 슬레이트 그라디언트
    context.saveGState()
    context.addPath(squirclePath(in: plate))
    context.clip()
    fillVerticalGradient(context, in: plate, from: Palette.backgroundTop, to: Palette.backgroundBottom)

    // 2. 상단 소프트 조명 (90° Top-Down Lighting)
    let highlight = CGRect(x: plate.minX, y: plate.minY, width: plate.width, height: plate.height * 0.5)
    fillVerticalGradient(
        context, in: highlight,
        from: CGColor(red: 1, green: 1, blue: 1, alpha: 0.08),
        to: CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    )

    // 3. Apple 정품 1px 마이크로 이너 베벨 림 라이트
    context.saveGState()
    context.addPath(squirclePath(in: plate))
    context.clip()
    context.addPath(squirclePath(in: plate.insetBy(dx: 4, dy: 4)))
    context.addPath(squirclePath(in: plate))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    context.restoreGState()

    // 4. 중앙 고급 코튼 페이퍼 메모 카드 렌더링
    switch variant {
    case .tilted:
        drawNote(context, tilt: -2.8, fold: 48)
    case .upright:
        drawNote(context, tilt: 0, fold: 48)
    }

    context.restoreGState()
}

private func drawNote(_ context: CGContext, tilt: CGFloat, fold: CGFloat) {
    let card = CGRect(x: 254, y: 228, width: 516, height: 568)

    context.saveGState()
    context.translateBy(x: card.midX, y: card.midY)
    context.rotate(by: tilt * .pi / 180)
    context.translateBy(x: -card.midX, y: -card.midY)

    // A. 2중 물리 섀도우: 1차 원거리 앰비언트 섀도우
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 38,
                      color: CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 0.42))
    context.addPath(notePath(in: card, cornerRadius: 40, fold: fold))
    context.setFillColor(Palette.paperTop)
    context.fillPath()
    context.restoreGState()

    // B. 2중 물리 섀도우: 2차 근접 접촉 섀도우 (Contact Shadow)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -5), blur: 10,
                      color: CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 0.28))
    context.addPath(notePath(in: card, cornerRadius: 40, fold: fold))
    context.setFillColor(Palette.paperTop)
    context.fillPath()
    context.restoreGState()

    // C. 코튼 종이 본체 텍스처 & 그라디언트 채우기
    context.saveGState()
    context.addPath(notePath(in: card, cornerRadius: 40, fold: fold))
    context.clip()
    fillVerticalGradient(context, in: card, from: Palette.paperTop, to: Palette.paperBottom)

    // C-1. 은은한 도트 그리드 (미세 크래프트 디테일)
    let dotSpacing: CGFloat = 46
    let dotRadius: CGFloat = 2.2
    for x in stride(from: card.minX + 54, through: card.maxX - 54, by: dotSpacing) {
        for y in stride(from: card.minY + 60, through: card.maxY - 60, by: dotSpacing) {
            context.addEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        }
    }
    context.setFillColor(Palette.subtleDot)
    context.fillPath()

    // C-2. 상단 1px 에지 하이라이트
    context.setStrokeColor(Palette.paperEdge)
    context.setLineWidth(2)
    context.move(to: CGPoint(x: card.minX + 40, y: card.minY + 1))
    context.addLine(to: CGPoint(x: card.maxX - 40, y: card.minY + 1))
    context.strokePath()
    context.restoreGState()

    // D. 접힌 모서리 (Corner Fold) 및 사실적 음영
    if fold > 0 {
        let foldTriangle = CGMutablePath()
        foldTriangle.move(to: CGPoint(x: card.maxX, y: card.maxY - fold))
        foldTriangle.addLine(to: CGPoint(x: card.maxX - fold, y: card.maxY))
        foldTriangle.addLine(to: CGPoint(x: card.maxX - fold, y: card.maxY - fold))
        foldTriangle.closeSubpath()

        // 접힌 부분 아래 부드러운 앰비언트 그림자
        context.saveGState()
        context.setShadow(offset: CGSize(width: -2, height: -2), blur: 5,
                          color: CGColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 0.35))
        context.addPath(foldTriangle)
        context.setFillColor(CGColor(red: 0.90, green: 0.88, blue: 0.84, alpha: 1))
        context.fillPath()
        context.restoreGState()

        // 접힌 면 자체의 그라디언트
        context.saveGState()
        context.addPath(foldTriangle)
        context.clip()
        fillVerticalGradient(context, in: CGRect(x: card.maxX - fold, y: card.maxY - fold, width: fold, height: fold),
                             from: CGColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1),
                             to: CGColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1))
        context.restoreGState()
    }

    // E. 만년필 잉크 획 (딥 인디고 첫 줄 + 테이퍼드 앰버 둘째 줄)
    context.setLineWidth(44)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.setStrokeColor(Palette.deepInk)
    context.addPath(firstLinePath(in: card))
    context.strokePath()

    context.setFillColor(Palette.amberInk)
    context.addPath(strokeCap(at: trailingLineStart(in: card), width: 44))
    context.fillPath()
    context.addPath(trailingLinePath(in: card, weight: 44))
    context.fillPath()

    // F. 상단 브라스(황동) 클립 (고급 문구류 디테일)
    let clipOuter = CGRect(x: card.minX + 64, y: card.minY - 18, width: 34, height: 76)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -3), blur: 6,
                      color: CGColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 0.35))
    
    // 외부 클립 바디
    let clipPath = CGMutablePath()
    clipPath.addRoundedRect(in: clipOuter, cornerWidth: 17, cornerHeight: 17)
    context.addPath(clipPath)
    context.clip()
    fillVerticalGradient(context, in: clipOuter, from: Palette.brassTop, to: Palette.brassBottom)
    context.restoreGState()

    // 클립 내부 음영 및 하이라이트 (금속성 와이어 느낌)
    context.saveGState()
    let clipInner = clipOuter.insetBy(dx: 7, dy: 7)
    let clipInnerPath = CGMutablePath()
    clipInnerPath.addRoundedRect(in: clipInner, cornerWidth: 10, cornerHeight: 10)
    context.addPath(clipInnerPath)
    context.clip()
    fillVerticalGradient(context, in: clipInner, from: CGColor(red: 0.995, green: 0.99, blue: 0.975, alpha: 1),
                         to: CGColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1))
    context.restoreGState()

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

func renderIcon(size: CGFloat, variant: Variant) -> CGImage? {
    guard let context = makeContext(size: size) else { return nil }
    drawIcon(context, size: size, variant: variant)
    return context.makeImage()
}

func renderTemplate(size: CGFloat) -> CGImage? {
    guard let context = makeContext(size: size) else { return nil }
    drawTemplateMark(context, size: size)
    return context.makeImage()
}

// MARK: - 비교 시트

/// 두 방향을 여러 크기로 나란히 그려 눈으로 고르게 한다.
func renderComparisonSheet() -> CGImage? {
    let sizes: [CGFloat] = [256, 128, 64, 32, 16]
    let width: CGFloat = 980
    let height: CGFloat = 330

    guard let sheet = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    sheet.setFillColor(CGColor(gray: 0.60, alpha: 1))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))

    var x: CGFloat = 26
    let topY = height - 30
    for size in sizes {
        if let image = renderIcon(size: size * 3, variant: .upright) {
            sheet.draw(image, in: CGRect(x: x, y: topY - size, width: size, height: size))
        }
        x += size + 22
    }

    // 메뉴바 템플릿은 밝은 배경과 어두운 배경 양쪽에서, 실제 크기와 확대로 본다.
    for (index, gray) in [0.95, 0.16].enumerated() {
        let box = CGRect(x: 690 + CGFloat(index) * 140, y: height - 200, width: 130, height: 160)
        sheet.setFillColor(CGColor(gray: gray, alpha: 1))
        sheet.fill(box)
        for (slotIndex, glyph) in [CGFloat(18), 54].enumerated() {
            guard let template = renderTemplate(size: glyph * 3) else { continue }
            let slot = CGRect(x: box.midX - glyph / 2,
                              y: box.maxY - 40 - CGFloat(slotIndex) * 76 - glyph / 2,
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

if arguments.contains("--sheet") {
    guard let sheet = renderComparisonSheet() else { exit(1) }
    let url = outputDirectory.appending(path: "comparison.png")
    try write(sheet, to: url)
    print(url.path(percentEncoded: false))
    exit(0)
}

let variant = arguments.firstIndex(of: "--variant")
    .flatMap { arguments.indices.contains($0 + 1) ? Variant(rawValue: arguments[$0 + 1]) : nil }
    ?? .upright

// .iconset 규격: 16~512 의 1x/2x
let iconset = outputDirectory.appending(path: "AppIcon.iconset", directoryHint: .isDirectory)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        guard let image = renderIcon(size: CGFloat(base * scale), variant: variant) else { continue }
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
