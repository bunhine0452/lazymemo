import Foundation

/// 사용자가 바꿀 수 있는 것들 (설계문서 §5.1 의 `settings.json`).
///
/// **비어 있는 것이 기본이다.** 값이 `nil` 이면 앱이 정한 기본값을 쓴다 —
/// 이렇게 두면 기본값을 나중에 고쳐도 한 번도 손대지 않은 사용자에게 그대로
/// 따라가고, 파일에는 사용자가 실제로 정한 것만 남는다.
public struct Settings: Codable, Sendable, Equatable {
    /// 빠른 입력 단축키. `nil` 이면 기본 조합(⌥⌘N).
    public var hotkeyKeyCode: UInt32?
    public var hotkeyModifiers: UInt32?

    /// 링크를 붙였을 때 제목과 그림을 가져와 카드로 보일지.
    ///
    /// **이것을 켜면 앱이 네트워크를 쓴다.** 기본 상태에서 네트워크를 쓰지
    /// 않는다는 약속(§9.3)이 여기서 갈리므로, 값을 파일에 남겨 사용자가 언제든
    /// 확인하고 되돌릴 수 있게 한다.
    public var embedsLinks: Bool?

    /// 바탕화면 종이가 얼마나 진한가. `nil` 이면 불투명한 종이.
    ///
    /// 재질은 하나(§14.5)라는 원칙과 부딪히는 유일한 설정이다. 유리를 쓰지
    /// 않기로 한 이유는 "반투명한 면 위의 글은 씻겨 나간다" 였고 그 판단은
    /// 지금도 옳지만, **바탕화면을 덮는다**는 불편은 그것과 다른 종류의
    /// 불편이다. 그래서 고를 수 있게 두되 기본은 불투명한 종이로 남긴다.
    public var paperOpacity: Double?

    /// 메모 폴더를 기본 자리에서 옮겼다면 그 자리 (설계문서 §5.1).
    ///
    /// **정본만 옮긴다.** 파생물(`index.sqlite`·`layout.json`·이 파일)은 언제나
    /// Application Support 에 남는다 — 지워도 되는 것과 지우면 안 되는 것이
    /// 같은 폴더에 섞이면 "통째로 지워도 Vault 만 있으면 복원된다"(D4)가 깨진다.
    ///
    /// 값이 `nil` 이면 `~/Documents/lazymemo`. 적힌 폴더가 없어졌으면 앱은
    /// 기본 자리로 돌아가고 메뉴가 그 사실을 적는다 — 조용히 빈 폴더를 만들면
    /// 사용자는 메모가 전부 사라진 것으로 본다.
    public var vaultPath: String?

    /// 첫 장(안내 종이)을 이미 놓았는가.
    ///
    /// 이것 하나가 "처음 켠 것" 의 유일한 근거다. 안내를 두 번 놓으면 그건
    /// 안내가 아니라 치울 거리이므로, 종이를 만들기 **전에** 적는다.
    public var greeted: Bool?

    public init(
        hotkeyKeyCode: UInt32? = nil,
        hotkeyModifiers: UInt32? = nil,
        embedsLinks: Bool? = nil,
        paperOpacity: Double? = nil,
        vaultPath: String? = nil,
        greeted: Bool? = nil
    ) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.embedsLinks = embedsLinks
        self.paperOpacity = paperOpacity
        self.vaultPath = vaultPath
        self.greeted = greeted
    }

    public static let `default` = Settings()

    /// 앱이 뜨기 **전에** 이 한 값만 읽는다 (`AppPaths.resolve`).
    ///
    /// 저장소를 열려면 폴더를 알아야 하고, 폴더를 알려면 설정을 읽어야 한다.
    /// 그 고리를 여기서 끊는다 — 파생물 자리(Application Support)는 설정과
    /// 무관하게 언제나 같은 곳이므로 설정 파일은 늘 찾을 수 있다.
    public static func storedVaultPath(inSupport support: URL) -> String? {
        let location = support.appending(path: "settings.json", directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: location),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              let path = settings.vaultPath,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return path
    }
}

/// `settings.json` 을 읽고 쓴다.
///
/// 파생 데이터에 두지만 지워도 되는 것들과는 성격이 다르다 — 지우면 사용자가
/// 정한 것이 사라진다. 그래서 쓰기는 원자적으로 하고, 읽기에 실패하면
/// **비어 있는 설정으로 시작한다.** 깨진 파일 때문에 앱이 안 뜨는 것이
/// 설정이 초기화되는 것보다 훨씬 나쁘다.
public final class SettingsStore: @unchecked Sendable {
    private let location: URL
    private let queue = DispatchQueue(label: "lazymemo.settings")
    private var cached: Settings

    public init(location: URL) {
        self.location = location
        self.cached = Self.read(from: location) ?? .default
    }

    public var current: Settings {
        queue.sync { cached }
    }

    /// 값을 고치고 즉시 파일에 남긴다. 설정은 자주 바뀌지 않으므로 미루지 않는다.
    @discardableResult
    public func update(_ change: (inout Settings) -> Void) -> Settings {
        queue.sync {
            var updated = cached
            change(&updated)
            guard updated != cached else { return cached }
            cached = updated
            Self.write(updated, to: location)
            return updated
        }
    }

    private static func read(from location: URL) -> Settings? {
        guard let data = try? Data(contentsOf: location) else { return nil }
        return try? JSONDecoder().decode(Settings.self, from: data)
    }

    private static func write(_ settings: Settings, to location: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // 원자적 쓰기 — 중간에 죽어도 반쪽짜리 설정 파일이 남지 않는다.
        try? data.write(to: location, options: .atomic)
    }
}
