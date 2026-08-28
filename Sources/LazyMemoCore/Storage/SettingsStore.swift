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

    public init(
        hotkeyKeyCode: UInt32? = nil,
        hotkeyModifiers: UInt32? = nil,
        embedsLinks: Bool? = nil
    ) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.embedsLinks = embedsLinks
    }

    public static let `default` = Settings()
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
