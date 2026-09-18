import Foundation

/// 테마 하나의 이름표. **ASCII 로 고정된다** — 설정 파일과 App Group 의
/// defaults 에 그대로 적히고 위젯이 그것을 읽으므로, 한 번 정한 id 는 바뀌지
/// 않는다 (보이는 이름은 표가 옮긴다).
public enum ThemeID: String, Sendable, Codable, CaseIterable, Hashable {
    case creamForest = "cream-forest"
    case midnight
    case sepia
    case inkAndPaper = "ink-and-paper"
    case spring
    case forestNight = "forest-night"
    case sea
    case rose

    /// 모르는 id 가 적혀 있으면 기본으로 — 앞선 판의 파일을 새 판이 열 때,
    /// 또는 사람이 손으로 잘못 적었을 때 앱이 뜨지 못하면 안 된다.
    public static func parsed(_ raw: String?) -> ThemeID {
        guard let raw, let id = ThemeID(rawValue: raw) else { return .creamForest }
        return id
    }
}

/// 한 외관에서 쓰는 색 한 벌.
///
/// **면을 칠하는 색과 글자로 쓰는 색을 가른다** — 이 앱이 세 번 틀린 자리다
/// (`Theme.accentInk`·`Theme.highlightInk`·`Paper.linkNSColor`). 밝은 호박색은
/// 칠하면 또렷하고 쓰면 안 읽힌다. 그래서 `accent`/`accentInk`,
/// `highlight`/`highlightInk` 가 각각 두 칸이다.
public struct ThemeVariant: Sendable, Equatable {
    /// 맨 종이.
    public var surface: ThemeRGB
    /// 목록의 종이 한 장 — 바탕과 명도만 달리해 경계를 만든다 (폰의 `Paper.card`).
    public var card: ThemeRGB
    /// 종이 위의 잉크.
    public var ink: ThemeRGB
    /// 둘째 줄·시각·안내. 잉크를 묽게 쓰므로 alpha 가 든다.
    public var secondaryInk: ThemeRGB
    /// 주요 행동의 **면**.
    public var accent: ThemeRGB
    /// 그 면 위의 글자.
    public var onAccent: ThemeRGB
    /// 같은 강조색을 종이 위의 **글자·아이콘**으로 쓸 때.
    public var accentInk: ThemeRGB
    /// 오늘·지금을 가리키는 **면**.
    public var highlight: ThemeRGB
    /// 같은 색을 **글자**로 쓸 때.
    public var highlightInk: ThemeRGB
    /// 그 글자가 앉는 칩의 바탕 (alpha).
    public var highlightWash: ThemeRGB
    /// 본문 안의 링크.
    public var link: ThemeRGB
    /// 도트 그리드의 세기. 색은 종이의 잉크가 정하므로(값싼 방법 — §8.2) 여기서는
    /// 묽기만 잡는다. `ruleInk` 를 채운 테마는 그 색으로 고정한다 — 무채로 가는 테마.
    public var ruleOpacity: Double
    public var ruleInk: ThemeRGB?
    /// **이 종이가 어두운가.** 외관이 아니라 이것이 기준이다 — 「미드나잇」은
    /// 빛 모드에서도 어두운 종이라, 가장자리의 두께·그림자·주말 색을
    /// `colorScheme` 으로 고르면 그 테마에서만 전부 뒤집힌다.
    public var darkPaper: Bool

    public init(
        surface: ThemeRGB, card: ThemeRGB, ink: ThemeRGB, secondaryInk: ThemeRGB,
        accent: ThemeRGB, onAccent: ThemeRGB, accentInk: ThemeRGB,
        highlight: ThemeRGB, highlightInk: ThemeRGB, highlightWash: ThemeRGB,
        link: ThemeRGB, ruleOpacity: Double, ruleInk: ThemeRGB? = nil, darkPaper: Bool
    ) {
        self.surface = surface
        self.card = card
        self.ink = ink
        self.secondaryInk = secondaryInk
        self.accent = accent
        self.onAccent = onAccent
        self.accentInk = accentInk
        self.highlight = highlight
        self.highlightInk = highlightInk
        self.highlightWash = highlightWash
        self.link = link
        self.ruleOpacity = ruleOpacity
        self.ruleInk = ruleInk
        self.darkPaper = darkPaper
    }
}

/// 테마 한 벌 — 빛·어둠 두 종이와, 여섯 메모 색.
///
/// **여섯 잉크는 외관마다 갈리지 않는다.** 지금 코드가 그렇고(`MemoColor.ink` 에
/// 외관 분기가 없다) 그래야 옳다 — 잉크를 종이로 눕히는 비율(`PaperTint`)이
/// 어둠을 이미 따로 잡고 있어서, 잉크까지 둘로 나누면 같은 일을 두 곳에서 한다.
public struct ThemeSpec: Sendable, Equatable {
    public let id: ThemeID
    /// 사람에게 보이는 이름.
    public let name: String
    /// 설정 창의 견본 밑에 붙는 한 줄.
    public let blurb: String
    public let light: ThemeVariant
    public let dark: ThemeVariant
    /// 대비 높임을 손으로 잡은 테마만. 비우면 `hardened()` 가 만든다.
    public let lightHighContrast: ThemeVariant?
    public let darkHighContrast: ThemeVariant?
    public let memoInks: [MemoColor: ThemeRGB]

    public init(
        id: ThemeID, name: String, blurb: String,
        light: ThemeVariant, dark: ThemeVariant,
        lightHighContrast: ThemeVariant? = nil, darkHighContrast: ThemeVariant? = nil,
        memoInks: [MemoColor: ThemeRGB]
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.light = light
        self.dark = dark
        self.lightHighContrast = lightHighContrast
        self.darkHighContrast = darkHighContrast
        self.memoInks = memoInks
    }

    public func variant(dark isDark: Bool, highContrast: Bool = false) -> ThemeVariant {
        guard highContrast else { return isDark ? dark : light }
        if let hand = isDark ? darkHighContrast : lightHighContrast { return hand }
        return (isDark ? dark : light).hardened()
    }

    public func ink(_ color: MemoColor) -> ThemeRGB {
        memoInks[color] ?? ThemeCatalog.creamForest.memoInks[color] ?? ThemeRGB(0.52, 0.51, 0.48)
    }
}

extension ThemeVariant {
    /// 대비 높임 — **손으로 안 잡은 테마는 여기서 만든다.**
    ///
    /// 여덟 테마 × 네 벌을 전부 손으로 적으면 서른두 벌이고, 그중 절반은
    /// 「조금 더 희게, 조금 더 검게」를 되풀이한 값이다. 되풀이하는 것은 코드가
    /// 한다 — 종이는 제 방향으로 30%, 잉크는 반대로 40% 가고, 글자로 쓰는 색들은
    /// 그 종이 위에서 다시 바닥까지 끌어올린다.
    public func hardened() -> ThemeVariant {
        let pole: ThemeRGB = darkPaper ? .black : .white
        let counter: ThemeRGB = darkPaper ? .white : .black
        var hard = self
        hard.surface = surface.blended(0.30, with: pole)
        hard.card = card.blended(0.30, with: pole)
        hard.ink = ink.blended(0.40, with: counter)
        hard.secondaryInk = secondaryInk.opacity(min(1, secondaryInk.alpha + 0.16))
            .legible(on: hard.surface, ratio: ThemeContrast.secondary)
        hard.accentInk = accentInk.legible(on: hard.surface, ratio: ThemeContrast.text)
        hard.highlightInk = highlightInk.legible(on: hard.surface, ratio: ThemeContrast.secondary)
        hard.link = link.legible(on: hard.surface, ratio: ThemeContrast.text)
        hard.onAccent = onAccent.legible(on: hard.accent, ratio: ThemeContrast.text)
        hard.ruleOpacity = min(1, ruleOpacity * 1.4)
        return hard
    }
}

/// 이 앱이 지키기로 한 바닥 (WCAG AA).
public enum ThemeContrast {
    /// 본문 크기의 글.
    public static let text = 4.5
    /// 보조 글·칩의 글씨처럼 작지 않게 쓰는 것.
    public static let secondary = 3.0
}

extension ThemeVariant {
    /// 한두 칸만 갈아 끼운 사본 — 대비 높임 판처럼 «거의 같은데 종이만 더 흰» 벌.
    public func replacing(
        surface: ThemeRGB? = nil, card: ThemeRGB? = nil, ink: ThemeRGB? = nil
    ) -> ThemeVariant {
        var copy = self
        if let surface { copy.surface = surface }
        if let card { copy.card = card }
        if let ink {
            copy.ink = ink
            // 보조 글은 잉크를 묽게 쓰는 것이라 잉크를 갈면 함께 간다.
            copy.secondaryInk = ink.opacity(secondaryInk.alpha)
        }
        return copy
    }
}
