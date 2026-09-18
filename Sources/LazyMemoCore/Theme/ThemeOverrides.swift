import Foundation

/// 고른 테마 **위에** 사람이 얹는 것.
///
/// 테마를 여덟 벌 주는 것과 「원하는 대로 고치게」 하는 것은 다른 요구다.
/// 다만 이 앱에서 색은 장식이 아니라 **읽히는 일**이라(§8.2), 고른 색이 글을
/// 안 읽히게 만들면 그건 고를 자유가 아니라 망가뜨릴 자유다. 그래서 얹는 것은
/// 넷으로 조이고, 그 넷은 전부 **바닥(WCAG AA) 위로 되끌어 올린 뒤** 쓴다
/// (`ThemeRGB.legible`).
///
/// 비어 있는 것이 기본이다 — `Settings` 의 다른 값들과 같은 규칙.
public struct ThemeOverrides: Codable, Sendable, Equatable {
    /// 주요 행동의 면 색. 이것만 정하면 **글자 색은 앱이 만든다** (아래 유도 규칙).
    public var accent: ThemeRGB?
    /// 종이에 스미는 색. 종이를 갈아 끼우는 것이 아니라 **스미게** 하는 것이라,
    /// 진한 색을 골라도 종이는 종이로 남는다 (§14.5 — 색이 종이를 잡아먹지 않는다).
    public var paperTint: ThemeRGB?
    /// 잉크. 종이 위에서 4.5:1 아래로는 내려가지 않는다.
    public var ink: ThemeRGB?
    /// 글자 크기 한 칸 (-1 … +2). 층의 **비율**은 그대로고 전체가 같이 커진다 —
    /// 제목만 키우면 그건 다른 디자인이지 큰 글자가 아니다.
    public var textStep: Int?
    /// 종이 결. 눈에 띄면 잡티가 되므로 원래 아주 옅지만, 아예 싫은 사람이 있다.
    public var paperTexture: Bool?

    public init(
        accent: ThemeRGB? = nil, paperTint: ThemeRGB? = nil, ink: ThemeRGB? = nil,
        textStep: Int? = nil, paperTexture: Bool? = nil
    ) {
        self.accent = accent
        self.paperTint = paperTint
        self.ink = ink
        self.textStep = textStep.map { min(max($0, Self.minimumStep), Self.maximumStep) }
        self.paperTexture = paperTexture
    }

    public static let none = ThemeOverrides()
    public var isEmpty: Bool { self == .none }

    public static let minimumStep = -1
    public static let maximumStep = 2

    /// 한 칸이 얼마인가. 층의 비율을 지키려면 **곱**이어야 한다 — pt 를 더하면
    /// 10pt 짜리 꼬리글이 14pt 본문보다 많이 자란다.
    public static func scale(step: Int?) -> Double {
        switch min(max(step ?? 0, minimumStep), maximumStep) {
        case -1: 0.92
        case 1: 1.12
        case 2: 1.25
        default: 1.0
        }
    }

    public var textScale: Double { Self.scale(step: textStep) }
    public var step: Int { min(max(textStep ?? 0, Self.minimumStep), Self.maximumStep) }
}

// MARK: - 얹기

extension ThemeSpec {
    /// 얹은 것을 반영한 테마 한 벌.
    ///
    /// **차례가 뜻을 가진다.** ① 종이에 색을 스미고 ② 그 종이 위에서 잉크를
    /// 정하고 ③ 강조색을 얹은 뒤 ④ 글자로 쓰는 색들을 전부 그 종이 위에서 다시
    /// 잰다. 거꾸로 하면 종이를 바꾼 뒤 글자 색이 옛 종이 기준으로 남는다.
    public func applying(_ overrides: ThemeOverrides) -> ThemeSpec {
        guard !overrides.isEmpty else { return self }
        return ThemeSpec(
            id: id, name: name, blurb: blurb,
            light: light.applying(overrides),
            dark: dark.applying(overrides),
            lightHighContrast: variant(dark: false, highContrast: true).applying(overrides),
            darkHighContrast: variant(dark: true, highContrast: true).applying(overrides),
            memoInks: memoInks
        )
    }
}

extension ThemeVariant {
    /// 얹은 것을 이 한 벌에.
    ///
    /// **유도 규칙** (설정 창의 바닥 글이 말하는 그것):
    /// - 고른 강조색은 **면**이다. 그 위의 글자(`onAccent`)는 테마의 글자색을
    ///   그 면 위에서 4.5:1 까지 밀어 올린 것 — 밝은 면을 고르면 저절로 검어진다.
    /// - 같은 색을 **종이 위의 글자**로 쓸 때(`accentInk`)는 종이 반대쪽으로
    ///   가라앉힌다. 밝은 종이면 어둡게, 어두운 종이면 밝게. 호박색에서 한 번
    ///   겪은 일을 사용자의 색에서 되풀이하지 않는다 (`Theme.highlightInk`).
    /// - 종이 색은 **스미는 것**이라 16% 만 눕힌다. 그래도 잉크가 4.5:1 아래로
    ///   내려가면 그만큼 물러선다 — 고른 색보다 읽히는 것이 먼저다.
    public func applying(_ overrides: ThemeOverrides) -> ThemeVariant {
        var next = self

        if let tint = overrides.paperTint {
            next.surface = Self.bled(surface, with: tint, ink: overrides.ink ?? ink)
            next.card = Self.bled(card, with: tint, ink: overrides.ink ?? ink)
        }

        if let chosen = overrides.ink {
            next.ink = chosen.legible(on: next.surface, ratio: ThemeContrast.text)
            next.secondaryInk = next.ink.opacity(secondaryInk.alpha)
        } else if overrides.paperTint != nil {
            next.ink = ink.legible(on: next.surface, ratio: ThemeContrast.text)
            next.secondaryInk = next.ink.opacity(secondaryInk.alpha)
        }

        if let accent = overrides.accent {
            next.accent = accent
            next.onAccent = onAccent.legible(on: accent, ratio: ThemeContrast.text)
            next.accentInk = accent.legible(on: next.surface, ratio: ThemeContrast.text)
        }

        // 종이가 달라졌으면 종이 위의 글은 전부 다시 잰다.
        next.secondaryInk = next.secondaryInk.legible(on: next.surface, ratio: ThemeContrast.secondary)
        next.accentInk = next.accentInk.legible(on: next.surface, ratio: ThemeContrast.text)
        next.highlightInk = next.highlightInk.legible(on: next.surface, ratio: ThemeContrast.secondary)
        next.link = next.link.legible(on: next.surface, ratio: ThemeContrast.text)
        next.onAccent = next.onAccent.legible(on: next.accent, ratio: ThemeContrast.text)
        return next
    }

    /// 종이에 색을 눕힌다 — 읽히는 데까지만.
    ///
    /// 16% 로 시작해 잉크가 바닥을 못 지키면 2%씩 물러난다. 0 까지 물러나면
    /// 원래 종이다 — 「고른 색이 안 보인다」가 「글이 안 보인다」보다 낫다.
    private static func bled(_ paper: ThemeRGB, with tint: ThemeRGB, ink: ThemeRGB) -> ThemeRGB {
        var fraction = 0.16
        while fraction > 0 {
            let mixed = paper.blended(fraction, with: tint.opaque)
            if ink.contrast(against: mixed) >= ThemeContrast.text { return mixed }
            fraction -= 0.02
        }
        return paper
    }
}
