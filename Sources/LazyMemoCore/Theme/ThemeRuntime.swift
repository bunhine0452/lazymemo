import Foundation

/// 지금 쓰는 테마 한 벌 — 고른 것 + 얹은 것.
public struct ResolvedTheme: Sendable, Equatable {
    public let id: ThemeID
    public let overrides: ThemeOverrides
    /// 얹은 것까지 반영한 색.
    public let spec: ThemeSpec
    /// 네 벌을 미리 지어 둔다 — 빛·어둠 × 평소·대비 높임.
    ///
    /// **그릴 때마다 지으면 안 된다.** 손으로 안 잡은 테마의 대비 높임 판은
    /// 색마다 바닥까지 끌어올리는 되풀이(`ThemeRGB.legible`)로 만들어지는데,
    /// 그 계산이 글자 하나 그릴 때마다 돈다. 한 번 지어 들고 있는다.
    private let variants: [ThemeVariant]

    public init(id: ThemeID, overrides: ThemeOverrides = .none) {
        self.id = id
        self.overrides = overrides
        let spec = ThemeCatalog.spec(id).applying(overrides)
        self.spec = spec
        self.variants = [
            spec.variant(dark: false), spec.variant(dark: true),
            spec.variant(dark: false, highContrast: true), spec.variant(dark: true, highContrast: true),
        ]
    }

    public static let `default` = ResolvedTheme(id: .creamForest)

    public var textScale: Double { overrides.textScale }
    public var paperTexture: Bool { overrides.paperTexture ?? true }

    public func variant(dark: Bool, highContrast: Bool = false) -> ThemeVariant {
        variants[(highContrast ? 2 : 0) + (dark ? 1 : 0)]
    }

    public func ink(_ color: MemoColor) -> ThemeRGB { spec.ink(color) }
}

/// **그릴 때 읽는 자리.**
///
/// 화면의 색은 대부분 `NSColor(name:) { appearance in … }` · `UIColor { traits in … }`
/// 안에서 정해진다. 그 닫힘은 그리는 순간 아무 스레드에서나 불리므로 메인에
/// 매인 관찰 대상을 들여다볼 수 없다 — 그래서 값 자체는 잠금 하나로 지키는
/// 여기에 두고, 화면을 **다시 그리게 만드는 일**만 각 플랫폼의 관찰 대상
/// (`ThemeStore`·`ThemeModel`)이 맡는다.
///
/// `LAZYMEMO_THEME=<id>` 면 그 테마로 뜬다 — 화면 밖 렌더와 시험이 기계의 설정과
/// 상관없이 같은 그림을 얻는 길 (`scripts/render-ui.sh`).
public final class ThemeRuntime: @unchecked Sendable {
    public static let shared = ThemeRuntime()

    private let lock = NSLock()
    private var value: ResolvedTheme

    init(_ initial: ResolvedTheme? = nil) {
        value = initial ?? Self.atLaunch()
    }

    public var resolved: ResolvedTheme {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    public func set(_ next: ResolvedTheme) {
        lock.lock(); defer { lock.unlock() }
        value = next
    }

    public func variant(dark: Bool, highContrast: Bool = false) -> ThemeVariant {
        resolved.variant(dark: dark, highContrast: highContrast)
    }

    /// 앱이 뜰 때 한 번. 설정 파일은 아직 열리지 않았을 수 있으므로 App Group 의
    /// 거울을 본다 — 위젯이 보는 것과 같은 자리라 홈 화면과 앱이 같은 종이다.
    private static func atLaunch() -> ResolvedTheme {
        if let forced = ProcessInfo.processInfo.environment["LAZYMEMO_THEME"], !forced.isEmpty {
            return ResolvedTheme(id: ThemeID.parsed(forced))
        }
        return ThemeChoice.load()
    }
}

/// 고른 테마를 **앱 밖에서도 볼 수 있는 자리**에 적어 둔다.
///
/// 위젯 확장은 `settings.json` 을 읽지 않는다 — 저장소를 열지 않고 홈 화면에
/// 그림 하나를 그릴 뿐이다 (`NowSeen` 과 같은 사정). 그래서 고른 테마와 얹은
/// 것을 App Group 의 defaults 에 거울로 둔다. 위젯이 부르는 것은 한 줄이다:
/// `ThemeChoice.load().spec`.
///
/// 정본은 여전히 `settings.json` 이다 — 사람이 열어 고칠 수 있는 파일이 정본이고,
/// 이것은 그것을 따라 적히는 거울이다.
public enum ThemeChoice {
    private static let key = "theme-choice"

    /// 앱과 위젯이 같이 보는 defaults. App Group 이 없는 빌드(맥)는 표준 defaults 로.
    public static var shared: UserDefaults { UserDefaults(suiteName: AppPaths.appGroupIdentifier) ?? .standard }

    private struct Stored: Codable {
        var id: String
        var overrides: ThemeOverrides?
    }

    public static func save(
        id: ThemeID, overrides: ThemeOverrides = .none, defaults: UserDefaults = shared
    ) {
        let stored = Stored(id: id.rawValue, overrides: overrides.isEmpty ? nil : overrides)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    /// 위젯이 부르는 한 줄.
    public static func load(defaults: UserDefaults = shared) -> ResolvedTheme {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return .default }
        return ResolvedTheme(id: ThemeID.parsed(stored.id), overrides: stored.overrides ?? .none)
    }

    /// 거울을 지운다 — 「기본으로」.
    public static func clear(defaults: UserDefaults = shared) {
        defaults.removeObject(forKey: key)
    }
}
