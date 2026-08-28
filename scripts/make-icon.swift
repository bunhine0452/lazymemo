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

// MARK: - 팔레트

enum Palette {
    /// 배경 그라디언트 — 밤의 책상.
    static let backgroundTop = CGColor(red: 0.44, green: 0.41, blue: 0.72, alpha: 1)
    static let backgroundBottom = CGColor(red: 0.13, green: 0.11, blue: 0.26, alpha: 1)

    /// 획 그라디언트 — 크림에서 호박색으로.
    static let strokeTop = CGColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)
    static let strokeBottom = CGColor(red: 0.99, green: 0.78, blue: 0.35, alpha: 1)

    static let paperTop = CGColor(red: 1.0, green: 0.99, blue: 0.965, alpha: 1)
    static let paperBottom = CGColor(red: 0.96, green: 0.935, blue: 0.885, alpha: 1)
    static let ink = CGColor(red: 0.17, green: 0.16, blue: 0.29, alpha: 1)
    static let amber = CGColor(red: 0.99, green: 0.76, blue: 0.31, alpha: 1)
}

// MARK: - 도형

/// 애플식 연속 곡률 모서리에 가까운 초타원.
///
/// `CGPath(roundedRect:)` 의 원형 모서리는 시스템 아이콘 옆에 두면 미묘하게
/// 어색하다. n=5 초타원이 눈에 띄게 가깝다.
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
///
/// 아랫변을 늘어뜨리는 안은 버렸다 — 둥근 사각형의 아래가 처지면 사람은
/// 그것을 말풍선으로 읽는다. 종이는 종이답게 반듯해야 한다.
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

/// 접힌 모서리에 드러나는 종이 뒷면.
func foldPath(in rect: CGRect, fold: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
    path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY - fold))
    path.closeSubpath()
    return path
}

/// 첫 줄 — 반듯하게 쓴 글.
func firstLinePath(in card: CGRect) -> CGPath {
    let path = CGMutablePath()
    let inset = card.width * 0.18
    let y = card.minY + card.height * 0.38
    path.move(to: CGPoint(x: card.minX + inset, y: y))
    path.addLine(to: CGPoint(x: card.maxX - inset, y: y))
    return path
}

/// 굵기가 변하는 획. 3차 베지에 중심선을 따라가며 법선 방향으로
/// 폭을 보간해 채울 도형을 만든다.
///
/// CoreGraphics 의 stroke 는 굵기가 일정해서 이 표현을 못 한다. 끝이
/// 가늘어지는 획이 이 아이콘의 서명이라 직접 만들 값어치가 있다.
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
        // 끝으로 갈수록 빠르게 가늘어져야 "흐지부지"로 읽힌다.
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

/// 획 시작의 둥근 마무리. 본체와 같은 패스에 넣으면 감김 방향이 상쇄돼
/// 이가 빠진 자국이 생기므로 따로 칠한다.
func strokeCap(at point: CGPoint, width: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(
        x: point.x - width / 2, y: point.y - width / 2, width: width, height: width
    ), transform: nil)
}

/// 둘째 줄 — 쓰다 말고 흘러내린다.
///
/// **아이콘의 요지가 여기 있다.** 게으름을 그릇의 모양이 아니라 글씨의
/// 태도로 표현한다. 다 적지 않아도 남는다는 것이 이 앱의 약속이다.
///
/// 굵기가 일정하면 갈고리(✓)나 물결(~)로 읽힌다. 끝으로 갈수록 가늘어져야
/// "꺾였다"가 아니라 "흐지부지 됐다"가 된다.
func trailingLineStart(in card: CGRect) -> CGPoint {
    CGPoint(x: card.minX + card.width * 0.18, y: card.minY + card.height * 0.585)
}

func trailingLinePath(in card: CGRect, weight: CGFloat) -> CGPath {
    let start = trailingLineStart(in: card)

    // 직선 구간을 길게 두고 하강을 얕게 잡아야 장식 스와시가 아니라
    // "쓰다 만 글줄"로 읽힌다.
    // 꼬리를 너무 길고 가늘게 빼면 32px 에서 사라진다. 작은 크기에서도
    // "짧고 기운 둘째 줄"로는 남도록 길이와 끝 굵기를 잡았다.
    return taperedStroke(
        from: start,
        to: CGPoint(x: start.x + card.width * 0.50, y: start.y + card.height * 0.135),
        control1: CGPoint(x: start.x + card.width * 0.38, y: start.y),
        control2: CGPoint(x: start.x + card.width * 0.42, y: start.y + card.height * 0.075),
        startWidth: weight, endWidth: weight * 0.14
    )
}

/// 메뉴바처럼 작은 자리에서는 곡선이 뭉갠다. 기울어진 짧은 직선이
/// 같은 뜻을 전하면서 픽셀에서 살아남는다.
func trailingLineSimplified(in card: CGRect) -> CGPath {
    let path = CGMutablePath()
    let inset = card.width * 0.18
    let left = card.minX + inset
    let y = card.minY + card.height * 0.60

    path.move(to: CGPoint(x: left, y: y))
    path.addLine(to: CGPoint(x: left + card.width * 0.46, y: y + card.height * 0.13))
    return path
}

// MARK: - 그리기

/// 위에서 아래로 흐르는 선형 그라디언트를 현재 클립 안에 채운다.
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
    /// 살짝 기울어진 종이.
    case tilted = "a"
    /// 정면으로 놓인 종이.
    case upright = "b"
}

/// 1024 좌표계에서 그리고 마지막에 축소한다 — 크기마다 비례가 흔들리지 않는다.
func drawIcon(_ context: CGContext, size: CGFloat, variant: Variant) {
    let unit = size / 1024
    context.saveGState()
    // 원점을 좌상단으로 뒤집는다. 위치를 읽기 쉬워진다.
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: unit, y: -unit)

    // 아이콘 판. macOS 아이콘은 캔버스 가장자리에 여백을 둔다.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)

    context.saveGState()
    context.addPath(squirclePath(in: plate))
    context.clip()
    fillVerticalGradient(context, in: plate, from: Palette.backgroundTop, to: Palette.backgroundBottom)

    // 위쪽에서 들어오는 빛. 없으면 판이 납작해 보인다.
    let highlight = CGRect(x: plate.minX, y: plate.minY, width: plate.width, height: plate.height * 0.55)
    fillVerticalGradient(
        context, in: highlight,
        from: CGColor(red: 1, green: 1, blue: 1, alpha: 0.14),
        to: CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    )
    // 위 가장자리에 얇은 빛. macOS 아이콘의 입체감은 대부분 여기서 온다.
    context.saveGState()
    context.addPath(squirclePath(in: plate))
    context.clip()
    context.addPath(squirclePath(in: plate.insetBy(dx: 5, dy: 5)))
    context.addPath(squirclePath(in: plate))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    context.restoreGState()

    switch variant {
    case .tilted:
        drawNote(context, tilt: -3.5, fold: 0)
    case .upright:
        drawNote(context, tilt: 0, fold: 0)
    }

    context.restoreGState()
}

private func drawNote(_ context: CGContext, tilt: CGFloat, fold: CGFloat) {
    let card = CGRect(x: 274, y: 250, width: 476, height: 524)

    context.saveGState()
    context.translateBy(x: card.midX, y: card.midY)
    context.rotate(by: tilt * .pi / 180)
    context.translateBy(x: -card.midX, y: -card.midY)

    context.setShadow(offset: CGSize(width: 0, height: -20), blur: 48,
                      color: CGColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 0.45))
    // 그림자를 그리려면 한 번은 채워야 한다. 그 위에 그라디언트를 덮는다.
    context.addPath(notePath(in: card, cornerRadius: 44, fold: fold))
    context.setFillColor(Palette.paperTop)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // 종이에도 판과 같은 방향의 빛을 준다. 평평한 크림 한 색은 인쇄물처럼 보인다.
    context.saveGState()
    context.addPath(notePath(in: card, cornerRadius: 44, fold: fold))
    context.clip()
    fillVerticalGradient(context, in: card, from: Palette.paperTop, to: Palette.paperBottom)
    context.restoreGState()

    if fold > 0 {
        context.addPath(foldPath(in: card, fold: fold))
        context.setFillColor(CGColor(red: 0.84, green: 0.81, blue: 0.75, alpha: 1))
        context.fillPath()
    }

    context.setLineWidth(46)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.setStrokeColor(Palette.ink)
    context.addPath(firstLinePath(in: card))
    context.strokePath()

    context.setFillColor(Palette.amber)
    context.addPath(strokeCap(at: trailingLineStart(in: card), width: 46))
    context.fillPath()
    context.addPath(trailingLinePath(in: card, weight: 46))
    context.fillPath()

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
