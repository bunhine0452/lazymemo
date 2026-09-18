import Foundation

/// 테마가 다루는 색 한 개 — **플랫폼 없는 숫자**다.
///
/// `NSColor`·`UIColor` 는 각자의 프레임워크에 묶여 있고, 그것을 카탈로그에 두면
/// 맥과 폰이 같은 표를 못 쓴다. 지금 두 쪽은 같은 숫자를 **각자 적어 두고**
/// 있었다 (`Views/Theme.swift` · `ios/LazyMemo/Theme.swift` · 위젯의
/// `WidgetPaper.swift` — 세 벌). 한쪽을 고치면 다른 두 쪽이 조용히 어긋난다.
///
/// 그래서 색은 여기 sRGB 네 숫자로만 산다. 프레임워크의 색으로 바꾸는 일은
/// 각 플랫폼의 얇은 한 줄이 맡는다.
public struct ThemeRGB: Sendable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    /// 투명한 색도 테마의 값이다 — 보조 글(잉크 64%)·호박색 칩 바탕·도트 그리드가
    /// 전부 «잉크를 얼마나 묽게 쓰는가» 이고, 그 묽기가 종이에 따라 달라야 한다.
    public var alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, alpha: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    public func opacity(_ value: Double) -> ThemeRGB {
        ThemeRGB(red, green, blue, alpha: value)
    }

    public var opaque: ThemeRGB { ThemeRGB(red, green, blue) }

    public static let white = ThemeRGB(1, 1, 1)
    public static let black = ThemeRGB(0, 0, 0)
}

// MARK: - 사람이 읽고 고칠 수 있게

/// `settings.json` 은 사용자가 직접 열어 고칠 수 있는 파일이다 (설계문서 §5.1).
/// 거기에 `{"red":0.16,"green":0.32,...}` 세 줄이 박히면 고칠 수 있는 파일이
/// 아니라 그냥 기계의 파일이다 — **`"#295245"` 한 조각**으로 적는다.
extension ThemeRGB: Codable {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = ThemeRGB(hex: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "색은 #rrggbb 또는 #rrggbbaa 로 적습니다 — \(raw)"
            ))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    public var hex: String {
        func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
        let base = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
        return alpha >= 1 ? base : base + String(format: "%02X", byte(alpha))
    }

    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt32(text, radix: 16) else { return nil }
        let hasAlpha = text.count == 8
        let shift = hasAlpha ? 8 : 0
        let red = Double((value >> (16 + shift)) & 0xFF) / 255
        let green = Double((value >> (8 + shift)) & 0xFF) / 255
        let blue = Double((value >> shift) & 0xFF) / 255
        let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
        self.init(red, green, blue, alpha: alpha)
    }
}

// MARK: - 재는 자

/// 색을 눈으로 고르면 «좀 흐린가» 까지밖에 말할 수 없다. 테마가 여럿이 되는
/// 순간 그 «좀» 이 여덟 벌로 늘어나므로, 읽히는지는 **재서** 못 박는다
/// (`PaperPaletteTests` 가 여섯 색에 한 것과 같은 자리).
extension ThemeRGB {
    /// 감마를 벗긴 밝기 (WCAG relative luminance).
    public var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// 두 색의 대비 (WCAG). 본문 글은 4.5:1, 큰 글·보조 글은 3:1 이 바닥이다.
    public func contrast(against other: ThemeRGB) -> Double {
        let one = relativeLuminance, two = other.relativeLuminance
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    /// 묽은 색을 종이 위에 눕힌다 — 재기 전에 먼저 이것을 해야 한다.
    /// 잉크 64% 는 그 자체로 밝기를 갖지 않는다. 종이가 있어야 색이 된다.
    public func composited(over background: ThemeRGB) -> ThemeRGB {
        guard alpha < 1 else { return opaque }
        let mix = { (top: Double, bottom: Double) in top * alpha + bottom * (1 - alpha) }
        return ThemeRGB(
            mix(red, background.red), mix(green, background.green), mix(blue, background.blue)
        )
    }

    /// 두 색 사이 — 0 이면 이쪽, 1 이면 저쪽.
    public func blended(_ fraction: Double, with other: ThemeRGB) -> ThemeRGB {
        let f = min(max(fraction, 0), 1)
        return ThemeRGB(
            red + (other.red - red) * f,
            green + (other.green - green) * f,
            blue + (other.blue - blue) * f,
            alpha: alpha
        )
    }

    /// **읽힐 때까지 가라앉히거나 띄운다.**
    ///
    /// 사용자가 고른 강조색이 종이 위에서 1.5:1 이면 그것은 색이 아니라 얼룩이다
    /// (호박색 글씨에서 한 번 겪었다 — `Theme.highlightInk`). 그렇다고 고른 색을
    /// 버리면 고르게 한 의미가 없으므로, **색상은 지키고 밝기만** 종이 반대쪽으로
    /// 옮긴다: 밝은 종이면 검정 쪽으로, 어두운 종이면 흰 쪽으로 조금씩.
    ///
    /// 1% 씩 최대 100 걸음. 끝까지 가도 안 되면(있을 수 없지만) 순수한 검정·흰색이다.
    public func legible(on paper: ThemeRGB, ratio: Double) -> ThemeRGB {
        let background = paper.opaque
        guard composited(over: background).contrast(against: background) < ratio else { return self }
        let target: ThemeRGB = background.relativeLuminance > 0.5 ? .black : .white
        var step = 0.0
        while step < 1.0 {
            step += 0.01
            let candidate = blended(step, with: target)
            if candidate.composited(over: background).contrast(against: background) >= ratio {
                return candidate
            }
        }
        return target.opacity(alpha)
    }
}

// MARK: - 눈이 재는 거리

/// 두 종이가 **나란히 놓였을 때 다른 종이로 보이는가** (CIE Lab, ΔE).
///
/// sRGB 위의 거리로 재면 어두운 쪽을 과소평가한다 — 그 잣대를 믿었다가 어두운
/// 종이를 색 판으로 만든 적이 있다 (`PaperPaletteTests` 의 머리글). 여기서도
/// 같은 자를 쓴다.
extension ThemeRGB {
    public var lab: (l: Double, a: Double, b: Double) {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let r = linear(red), g = linear(green), b = linear(blue)
        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
        func f(_ t: Double) -> Double {
            t > 216.0 / 24389.0 ? pow(t, 1.0 / 3.0) : (841.0 / 108.0) * t + 4.0 / 29.0
        }
        let fx = f(x / 0.95047), fy = f(y), fz = f(z / 1.08883)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    public func distance(to other: ThemeRGB) -> Double {
        let one = lab, two = other.lab
        let dl = one.l - two.l, da = one.a - two.a, db = one.b - two.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
