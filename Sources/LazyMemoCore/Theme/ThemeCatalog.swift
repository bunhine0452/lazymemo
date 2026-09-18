import Foundation

/// 고를 수 있는 종이 — **여덟 벌의 문구류**.
///
/// 기준은 1판과 같다 (설계문서 §14.5): 좋은 노트이지 스큐어모피즘이 아니다.
/// 그래서 테마가 바꾸는 것은 **종이와 잉크의 색**뿐이고, 여백·글자 층·모서리
/// 반경 같은 형태의 규칙은 어느 테마에서도 같다 (docs/VISUAL_DESIGN.md 「테마」).
/// 색을 고르게 한다고 앱이 여덟 개가 되어서는 안 된다.
///
/// 「크림과 포레스트」의 숫자는 **오늘 화면에 있는 값 그대로다.** 한 번도 테마를
/// 고르지 않은 사람에게는 아무것도 달라지지 않아야 한다 (`ThemeCatalogTests` 가
/// 그 숫자를 따로 적어 두고 대조한다).
public enum ThemeCatalog {
    public static let all: [ThemeSpec] = [
        creamForest, midnight, sepia, inkAndPaper, spring, forestNight, sea, rose,
    ]

    public static let `default` = creamForest

    public static func spec(_ id: ThemeID) -> ThemeSpec {
        all.first { $0.id == id } ?? creamForest
    }

    // MARK: 여섯 잉크 — 메모의 신원

    /// 문구점의 여섯 (1판 그대로). 색은 메모가 **누구인지**를 말하는 것이라
    /// 테마가 함부로 흔들지 않는다 — 흔드는 테마도 여섯이 서로 갈리는 것은
    /// 지킨다 (`ThemeContrastTests`).
    public static let stationery: [MemoColor: ThemeRGB] = [
        .yellow: ThemeRGB(0.82, 0.66, 0.28),
        .green: ThemeRGB(0.42, 0.62, 0.42),
        .blue: ThemeRGB(0.36, 0.55, 0.72),
        .purple: ThemeRGB(0.58, 0.44, 0.72),
        .pink: ThemeRGB(0.78, 0.48, 0.56),
        .gray: ThemeRGB(0.52, 0.51, 0.48),
    ]

    /// 봄의 여섯 — 같은 자리에서 한 걸음 옅고 밝게.
    public static let pastel: [MemoColor: ThemeRGB] = [
        .yellow: ThemeRGB(0.88, 0.74, 0.36),
        .green: ThemeRGB(0.52, 0.74, 0.52),
        .blue: ThemeRGB(0.44, 0.64, 0.84),
        .purple: ThemeRGB(0.68, 0.52, 0.84),
        .pink: ThemeRGB(0.90, 0.58, 0.66),
        .gray: ThemeRGB(0.64, 0.63, 0.60),
    ]

    /// 어두운 종이를 위한 여섯 — 깊은 잉크. 어두운 종이는 색을 더 먹으므로
    /// (`PaperTint.dark`) 잉크 쪽에서 미리 가라앉혀 둔다.
    public static let deep: [MemoColor: ThemeRGB] = [
        .yellow: ThemeRGB(0.74, 0.58, 0.22),
        .green: ThemeRGB(0.34, 0.54, 0.36),
        .blue: ThemeRGB(0.28, 0.47, 0.68),
        .purple: ThemeRGB(0.50, 0.36, 0.68),
        .pink: ThemeRGB(0.72, 0.40, 0.50),
        .gray: ThemeRGB(0.46, 0.45, 0.43),
    ]

    // MARK: 크림과 포레스트 — 기본

    /// 기본 테마의 빛 종이. 대비 높임 판이 이것을 물려받으므로 이름을 준다 —
    /// `creamForest.light` 를 되짚으면 자기 자신을 만드는 중에 자기를 읽는다.
    static let creamLight = ThemeVariant(
        surface: ThemeRGB(0.980, 0.969, 0.949),
        card: ThemeRGB(1, 0.993, 0.978),
        ink: ThemeRGB(0.161, 0.149, 0.129),
        secondaryInk: ThemeRGB(0.161, 0.149, 0.129, alpha: 0.64),
        accent: ThemeRGB(0.16, 0.32, 0.27),
        onAccent: ThemeRGB(0.98, 0.98, 0.94),
        accentInk: ThemeRGB(0.16, 0.32, 0.27),
        highlight: ThemeRGB(0.99, 0.76, 0.31),
        highlightInk: ThemeRGB(0.56, 0.37, 0.05),
        highlightWash: ThemeRGB(0.97, 0.72, 0.24, alpha: 0.38),
        link: ThemeRGB(0.20, 0.40, 0.66),
        ruleOpacity: 0.07,
        darkPaper: false
    )

    static let creamDark = ThemeVariant(
        surface: ThemeRGB(0.137, 0.129, 0.118),
        card: ThemeRGB(0.185, 0.175, 0.16),
        ink: ThemeRGB(0.902, 0.886, 0.855),
        secondaryInk: ThemeRGB(0.902, 0.886, 0.855, alpha: 0.64),
        accent: ThemeRGB(0.16, 0.32, 0.27),
        onAccent: ThemeRGB(0.98, 0.98, 0.94),
        accentInk: ThemeRGB(0.65, 0.83, 0.73),
        highlight: ThemeRGB(0.99, 0.76, 0.31),
        highlightInk: ThemeRGB(0.99, 0.76, 0.31),
        highlightWash: ThemeRGB(0.99, 0.76, 0.31, alpha: 0.18),
        link: ThemeRGB(0.56, 0.75, 1.0),
        ruleOpacity: 0.08,
        darkPaper: true
    )

    /// 대비 높임 — **폰이 이미 손으로 잡아 둔 값 그대로다** (MOBILE_DESIGN §10).
    /// 더 희고 더 검은 종이·잉크만 갈리고 나머지는 평소 것을 쓴다.
    static let creamLightHigh = creamLight.replacing(
        surface: ThemeRGB(0.995, 0.990, 0.980), ink: ThemeRGB(0.08, 0.07, 0.06)
    )
    static let creamDarkHigh = creamDark.replacing(
        surface: ThemeRGB(0.06, 0.055, 0.05), card: ThemeRGB(0.14, 0.14, 0.14),
        ink: ThemeRGB(0.98, 0.97, 0.95)
    )

    public static let creamForest = ThemeSpec(
        id: .creamForest,
        name: L("크림과 포레스트"),
        blurb: L("미색 종이에 포레스트 초록"),
        light: creamLight,
        dark: creamDark,
        lightHighContrast: creamLightHigh,
        darkHighContrast: creamDarkHigh,
        memoInks: stationery
    )

    // MARK: 미드나잇 — 빛 모드에서도 어두운 종이

    public static let midnight = ThemeSpec(
        id: .midnight,
        name: L("미드나잇"),
        blurb: L("깊은 남색 종이에 미색 잉크"),
        light: ThemeVariant(
            surface: ThemeRGB(0.098, 0.114, 0.165),
            card: ThemeRGB(0.130, 0.148, 0.205),
            ink: ThemeRGB(0.940, 0.934, 0.910),
            secondaryInk: ThemeRGB(0.940, 0.934, 0.910, alpha: 0.64),
            accent: ThemeRGB(0.290, 0.400, 0.640),
            onAccent: ThemeRGB(0.970, 0.970, 0.940),
            accentInk: ThemeRGB(0.620, 0.750, 0.950),
            highlight: ThemeRGB(0.960, 0.800, 0.450),
            highlightInk: ThemeRGB(0.960, 0.800, 0.450),
            highlightWash: ThemeRGB(0.960, 0.800, 0.450, alpha: 0.18),
            link: ThemeRGB(0.600, 0.780, 1.0),
            ruleOpacity: 0.10,
            darkPaper: true
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.055, 0.067, 0.110),
            card: ThemeRGB(0.085, 0.100, 0.150),
            ink: ThemeRGB(0.925, 0.918, 0.890),
            secondaryInk: ThemeRGB(0.925, 0.918, 0.890, alpha: 0.64),
            accent: ThemeRGB(0.290, 0.400, 0.640),
            onAccent: ThemeRGB(0.970, 0.970, 0.940),
            accentInk: ThemeRGB(0.640, 0.760, 0.960),
            highlight: ThemeRGB(0.960, 0.800, 0.450),
            highlightInk: ThemeRGB(0.980, 0.820, 0.480),
            highlightWash: ThemeRGB(0.960, 0.800, 0.450, alpha: 0.18),
            link: ThemeRGB(0.600, 0.780, 1.0),
            ruleOpacity: 0.10,
            darkPaper: true
        ),
        memoInks: deep
    )

    // MARK: 세피아 — 양피지

    public static let sepia = ThemeSpec(
        id: .sepia,
        name: L("세피아"),
        blurb: L("바랜 양피지에 갈색 잉크"),
        light: ThemeVariant(
            surface: ThemeRGB(0.945, 0.906, 0.827),
            card: ThemeRGB(0.968, 0.936, 0.866),
            ink: ThemeRGB(0.196, 0.145, 0.098),
            secondaryInk: ThemeRGB(0.196, 0.145, 0.098, alpha: 0.66),
            accent: ThemeRGB(0.443, 0.263, 0.153),
            onAccent: ThemeRGB(0.973, 0.949, 0.894),
            accentInk: ThemeRGB(0.400, 0.235, 0.133),
            highlight: ThemeRGB(0.788, 0.549, 0.216),
            highlightInk: ThemeRGB(0.455, 0.298, 0.043),
            highlightWash: ThemeRGB(0.788, 0.549, 0.216, alpha: 0.34),
            link: ThemeRGB(0.216, 0.353, 0.561),
            ruleOpacity: 0.09,
            darkPaper: false
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.149, 0.125, 0.102),
            card: ThemeRGB(0.196, 0.169, 0.141),
            ink: ThemeRGB(0.925, 0.886, 0.804),
            secondaryInk: ThemeRGB(0.925, 0.886, 0.804, alpha: 0.66),
            accent: ThemeRGB(0.553, 0.353, 0.216),
            onAccent: ThemeRGB(0.980, 0.965, 0.925),
            accentInk: ThemeRGB(0.847, 0.651, 0.451),
            highlight: ThemeRGB(0.949, 0.749, 0.396),
            highlightInk: ThemeRGB(0.949, 0.749, 0.396),
            highlightWash: ThemeRGB(0.949, 0.749, 0.396, alpha: 0.18),
            link: ThemeRGB(0.596, 0.749, 0.973),
            ruleOpacity: 0.09,
            darkPaper: true
        ),
        memoInks: deep
    )

    // MARK: 흑백 잉크 — 읽기만 남긴다

    public static let inkAndPaper = ThemeSpec(
        id: .inkAndPaper,
        name: L("흑백 잉크"),
        blurb: L("색을 줄이고 읽기를 남긴다"),
        light: ThemeVariant(
            surface: ThemeRGB(0.988, 0.988, 0.984),
            card: ThemeRGB(1, 1, 1),
            ink: ThemeRGB(0.075, 0.075, 0.075),
            secondaryInk: ThemeRGB(0.075, 0.075, 0.075, alpha: 0.66),
            accent: ThemeRGB(0.129, 0.129, 0.129),
            onAccent: ThemeRGB(0.988, 0.988, 0.984),
            accentInk: ThemeRGB(0.129, 0.129, 0.129),
            highlight: ThemeRGB(0.400, 0.400, 0.400),
            highlightInk: ThemeRGB(0.298, 0.298, 0.298),
            highlightWash: ThemeRGB(0.400, 0.400, 0.400, alpha: 0.22),
            link: ThemeRGB(0.157, 0.259, 0.404),
            ruleOpacity: 0.07,
            ruleInk: ThemeRGB(0.075, 0.075, 0.075),
            darkPaper: false
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.102, 0.102, 0.102),
            card: ThemeRGB(0.145, 0.145, 0.145),
            ink: ThemeRGB(0.949, 0.949, 0.945),
            secondaryInk: ThemeRGB(0.949, 0.949, 0.945, alpha: 0.66),
            accent: ThemeRGB(0.855, 0.855, 0.851),
            onAccent: ThemeRGB(0.102, 0.102, 0.102),
            accentInk: ThemeRGB(0.855, 0.855, 0.851),
            highlight: ThemeRGB(0.700, 0.700, 0.700),
            highlightInk: ThemeRGB(0.800, 0.800, 0.800),
            highlightWash: ThemeRGB(0.700, 0.700, 0.700, alpha: 0.20),
            link: ThemeRGB(0.702, 0.792, 0.925),
            ruleOpacity: 0.10,
            ruleInk: ThemeRGB(0.949, 0.949, 0.945),
            darkPaper: true
        ),
        memoInks: stationery
    )

    // MARK: 봄 파스텔

    public static let spring = ThemeSpec(
        id: .spring,
        name: L("봄 파스텔"),
        blurb: L("환한 종이에 라즈베리"),
        light: ThemeVariant(
            surface: ThemeRGB(0.988, 0.980, 0.973),
            card: ThemeRGB(1, 0.996, 0.992),
            ink: ThemeRGB(0.192, 0.169, 0.180),
            secondaryInk: ThemeRGB(0.192, 0.169, 0.180, alpha: 0.64),
            accent: ThemeRGB(0.639, 0.235, 0.396),
            onAccent: ThemeRGB(0.992, 0.969, 0.976),
            accentInk: ThemeRGB(0.576, 0.196, 0.345),
            highlight: ThemeRGB(0.990, 0.780, 0.420),
            highlightInk: ThemeRGB(0.545, 0.361, 0.086),
            highlightWash: ThemeRGB(0.970, 0.750, 0.350, alpha: 0.34),
            link: ThemeRGB(0.220, 0.400, 0.660),
            ruleOpacity: 0.08,
            darkPaper: false
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.145, 0.133, 0.141),
            card: ThemeRGB(0.192, 0.176, 0.184),
            ink: ThemeRGB(0.918, 0.898, 0.902),
            secondaryInk: ThemeRGB(0.918, 0.898, 0.902, alpha: 0.64),
            accent: ThemeRGB(0.639, 0.235, 0.396),
            onAccent: ThemeRGB(0.992, 0.969, 0.976),
            accentInk: ThemeRGB(0.933, 0.596, 0.714),
            highlight: ThemeRGB(0.990, 0.780, 0.420),
            highlightInk: ThemeRGB(0.990, 0.780, 0.420),
            highlightWash: ThemeRGB(0.990, 0.780, 0.420, alpha: 0.18),
            link: ThemeRGB(0.600, 0.760, 1.0),
            ruleOpacity: 0.09,
            darkPaper: true
        ),
        memoInks: pastel
    )

    // MARK: 숲속 어둠

    public static let forestNight = ThemeSpec(
        id: .forestNight,
        name: L("숲속 어둠"),
        blurb: L("짙은 초록 종이에 세이지"),
        light: ThemeVariant(
            surface: ThemeRGB(0.114, 0.141, 0.125),
            card: ThemeRGB(0.149, 0.180, 0.161),
            ink: ThemeRGB(0.886, 0.902, 0.878),
            secondaryInk: ThemeRGB(0.886, 0.902, 0.878, alpha: 0.64),
            accent: ThemeRGB(0.259, 0.443, 0.353),
            onAccent: ThemeRGB(0.973, 0.980, 0.953),
            accentInk: ThemeRGB(0.612, 0.816, 0.694),
            highlight: ThemeRGB(0.902, 0.769, 0.400),
            highlightInk: ThemeRGB(0.902, 0.769, 0.400),
            highlightWash: ThemeRGB(0.902, 0.769, 0.400, alpha: 0.18),
            link: ThemeRGB(0.565, 0.769, 0.929),
            ruleOpacity: 0.10,
            darkPaper: true
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.071, 0.094, 0.082),
            card: ThemeRGB(0.102, 0.129, 0.114),
            ink: ThemeRGB(0.898, 0.914, 0.890),
            secondaryInk: ThemeRGB(0.898, 0.914, 0.890, alpha: 0.64),
            accent: ThemeRGB(0.259, 0.443, 0.353),
            onAccent: ThemeRGB(0.973, 0.980, 0.953),
            accentInk: ThemeRGB(0.639, 0.839, 0.718),
            highlight: ThemeRGB(0.902, 0.769, 0.400),
            highlightInk: ThemeRGB(0.902, 0.769, 0.400),
            highlightWash: ThemeRGB(0.902, 0.769, 0.400, alpha: 0.18),
            link: ThemeRGB(0.565, 0.769, 0.929),
            ruleOpacity: 0.10,
            darkPaper: true
        ),
        memoInks: deep
    )

    // MARK: 바다

    public static let sea = ThemeSpec(
        id: .sea,
        name: L("바다"),
        blurb: L("서늘한 종이에 남색"),
        light: ThemeVariant(
            surface: ThemeRGB(0.965, 0.976, 0.980),
            card: ThemeRGB(0.988, 0.996, 1.0),
            ink: ThemeRGB(0.106, 0.137, 0.157),
            secondaryInk: ThemeRGB(0.106, 0.137, 0.157, alpha: 0.64),
            accent: ThemeRGB(0.122, 0.353, 0.478),
            onAccent: ThemeRGB(0.965, 0.984, 0.992),
            accentInk: ThemeRGB(0.106, 0.322, 0.447),
            highlight: ThemeRGB(0.973, 0.749, 0.318),
            highlightInk: ThemeRGB(0.510, 0.361, 0.047),
            highlightWash: ThemeRGB(0.960, 0.720, 0.270, alpha: 0.36),
            link: ThemeRGB(0.145, 0.376, 0.588),
            ruleOpacity: 0.07,
            darkPaper: false
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.098, 0.114, 0.125),
            card: ThemeRGB(0.133, 0.153, 0.169),
            ink: ThemeRGB(0.867, 0.894, 0.910),
            secondaryInk: ThemeRGB(0.867, 0.894, 0.910, alpha: 0.64),
            accent: ThemeRGB(0.122, 0.353, 0.478),
            onAccent: ThemeRGB(0.965, 0.984, 0.992),
            accentInk: ThemeRGB(0.541, 0.769, 0.902),
            highlight: ThemeRGB(0.973, 0.749, 0.318),
            highlightInk: ThemeRGB(0.973, 0.749, 0.318),
            highlightWash: ThemeRGB(0.973, 0.749, 0.318, alpha: 0.18),
            link: ThemeRGB(0.565, 0.765, 1.0),
            ruleOpacity: 0.09,
            darkPaper: true
        ),
        memoInks: stationery
    )

    // MARK: 장미

    public static let rose = ThemeSpec(
        id: .rose,
        name: L("장미"),
        blurb: L("따뜻한 종이에 장미빛"),
        light: ThemeVariant(
            surface: ThemeRGB(0.984, 0.965, 0.961),
            card: ThemeRGB(1, 0.988, 0.984),
            ink: ThemeRGB(0.169, 0.141, 0.145),
            secondaryInk: ThemeRGB(0.169, 0.141, 0.145, alpha: 0.64),
            accent: ThemeRGB(0.561, 0.176, 0.286),
            onAccent: ThemeRGB(0.988, 0.965, 0.965),
            accentInk: ThemeRGB(0.525, 0.161, 0.267),
            highlight: ThemeRGB(0.949, 0.729, 0.373),
            highlightInk: ThemeRGB(0.529, 0.349, 0.055),
            highlightWash: ThemeRGB(0.940, 0.700, 0.300, alpha: 0.36),
            link: ThemeRGB(0.216, 0.388, 0.647),
            ruleOpacity: 0.07,
            darkPaper: false
        ),
        dark: ThemeVariant(
            surface: ThemeRGB(0.141, 0.122, 0.125),
            card: ThemeRGB(0.184, 0.161, 0.165),
            ink: ThemeRGB(0.910, 0.886, 0.890),
            secondaryInk: ThemeRGB(0.910, 0.886, 0.890, alpha: 0.64),
            accent: ThemeRGB(0.561, 0.176, 0.286),
            onAccent: ThemeRGB(0.988, 0.965, 0.965),
            accentInk: ThemeRGB(0.918, 0.596, 0.663),
            highlight: ThemeRGB(0.949, 0.729, 0.373),
            highlightInk: ThemeRGB(0.949, 0.729, 0.373),
            highlightWash: ThemeRGB(0.949, 0.729, 0.373, alpha: 0.18),
            link: ThemeRGB(0.596, 0.757, 1.0),
            ruleOpacity: 0.09,
            darkPaper: true
        ),
        memoInks: stationery
    )
}
