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

    /// `vaultPath` 에 다시 닿기 위한 열쇠 — 샌드박스 판(App Store)의 것이다
    /// (`VaultBookmark`).
    ///
    /// 샌드박스 안에서는 사용자가 패널로 고른 폴더라도 **다음 실행에는 닿을 수
    /// 없다.** 경로는 알지만 문이 잠긴다 — 열쇠는 security-scoped bookmark
    /// 하나뿐이고, 그것을 여기 같이 적어 둔다. 샌드박스 밖 판은 이 값이 있어도
    /// 없어도 경로로 간다.
    public var vaultBookmark: Data?

    /// 종이 위에서 Claude 를 부를 수 있게 할지 (`{#claude-tidy-action}`).
    ///
    /// **`claude` 가 없는 컴퓨터에서는 이 값이 무엇이든 아무 일도 없다.** 켜져
    /// 있어도 누르기 전에는 아무것도 나가지 않는다 — 자동으로 도는 것이 아니다.
    public var usesClaude: Bool?

    /// 찾아 둔 `claude` 의 자리. 켤 때마다 로그인 셸을 띄우지 않으려고 적어 둔다.
    public var claudePath: String?

    /// 적어 둔 자리에 가면 그 종이가 나오게 할지 (`PlaceWatcher`).
    ///
    /// **기본은 꺼짐이다.** `Always` 위치 권한은 이 앱이 요구하는 것 중 가장
    /// 무거운 것이라 — 앱을 안 보고 있을 때도 시스템이 자리를 알려 준다 —
    /// 「끌 수 있다」로는 모자라고 **켜는 것을 사람이 직접 해야 한다**로 잠근다.
    public var watchesPlaces: Bool?

    /// 아침마다 Claude 가 종이 한 장을 놓을지 (`MorningBrief`).
    ///
    /// **기본은 꺼짐이다.** 사용자가 누르지 않았는데 토큰을 쓰는 유일한 기능이라,
    /// 「끌 수 있다」로는 모자라고 **켜는 것을 사람이 직접 해야 한다**로 잠근다.
    public var morningBrief: Bool?

    /// 브리핑이 쓰는 종이. 매일 새로 만들지 않고 이 한 장을 다시 쓴다.
    public var briefMemoID: String?

    /// 달력에 시스템 캘린더의 일정도 함께 보일지.
    ///
    /// **켜져 있어도 달력을 열기 전에는 아무것도 묻지 않는다.** 캘린더 권한을
    /// 묻는 자리는 달력 창이 처음 열릴 때 하나뿐이다 (§8 — 첫 실행에서 사용자를
    /// 시스템 설정으로 보내지 않는다). `nil` 이면 켜짐.
    public var showsSystemEvents: Bool?

    /// 새 판이 나왔는지 GitHub 에 물어볼지 (`UpdateCheck`).
    ///
    /// **이것이 켜져 있으면 앱이 네트워크를 쓴다.** 링크 카드에 이어 두 번째로
    /// §9.3 의 약속이 갈리는 자리라, 같은 조건을 건다 — 끌 수 있고, 나가는 것은
    /// 주소 하나뿐이며(메모 본문도 판 번호도 보내지 않는다), 켜져 있다는 사실이
    /// 메뉴에서 보인다. `nil` 이면 켜짐.
    public var checksForUpdates: Bool?

    /// 첫 장(안내 종이)을 이미 놓았는가.
    ///
    /// 이것 하나가 "처음 켠 것" 의 유일한 근거다. 안내를 두 번 놓으면 그건
    /// 안내가 아니라 치울 거리이므로, 종이를 만들기 **전에** 적는다.
    public var greeted: Bool?

    /// 서랍의 폴더 이름들 — **차례와 빈 폴더를 위한 것이다** (`MemoFolders`).
    ///
    /// 어느 메모가 어느 폴더에 있는지는 파일이 안다 (`Memo.folder`). 여기
    /// 적는 것은 그 파일들만으로는 알 수 없는 둘뿐이다: 사람이 폴더를 어떤
    /// 차례로 두었는가, 그리고 아직 아무것도 안 넣은 폴더가 있는가. 이 값을
    /// 잃어도 메모는 제 폴더 이름표를 그대로 달고 있으므로 폴더는 되살아난다.
    public var folders: [String]?

    /// 약속 메모를 적으면 비서가 「어디서 출발하시나요?」를 물을지 (`RoutePlanner`). `nil` 이면 켜짐.
    ///
    /// 되물음에 답할 때만 네트워크를 쓴다 — 자리 이름을 지도에 묻고, 길을 잰다. 묻지 않고
    /// 나가는 것은 없다. 매번 「됐어」로 넘기는 사람은 여기서 끈다.
    public var asksRoutes: Bool?

    /// ODsay(대중교통 길찾기) API 키. 있으면 버스 번호·지하철역·환승까지 잰다; 없으면 애플 지도의
    /// 소요 시간만 안다. **이 기기의 값이다** — iCloud 로 건너가지 않는다.
    public var transitKey: String?

    public init(
        hotkeyKeyCode: UInt32? = nil,
        hotkeyModifiers: UInt32? = nil,
        embedsLinks: Bool? = nil,
        paperOpacity: Double? = nil,
        vaultPath: String? = nil,
        vaultBookmark: Data? = nil,
        usesClaude: Bool? = nil,
        claudePath: String? = nil,
        watchesPlaces: Bool? = nil,
        morningBrief: Bool? = nil,
        briefMemoID: String? = nil,
        showsSystemEvents: Bool? = nil,
        checksForUpdates: Bool? = nil,
        greeted: Bool? = nil,
        folders: [String]? = nil,
        asksRoutes: Bool? = nil,
        transitKey: String? = nil
    ) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.embedsLinks = embedsLinks
        self.paperOpacity = paperOpacity
        self.vaultPath = vaultPath
        self.vaultBookmark = vaultBookmark
        self.usesClaude = usesClaude
        self.claudePath = claudePath
        self.watchesPlaces = watchesPlaces
        self.morningBrief = morningBrief
        self.briefMemoID = briefMemoID
        self.showsSystemEvents = showsSystemEvents
        self.checksForUpdates = checksForUpdates
        self.greeted = greeted
        self.folders = folders
        self.asksRoutes = asksRoutes
        self.transitKey = transitKey
    }

    public static let `default` = Settings()

    /// 옮겨 둔 메모 폴더 — 경로와, 있으면 그 열쇠.
    public struct StoredVault: Sendable, Equatable {
        public let path: String
        public let bookmark: Data?
    }

    /// 앱이 뜨기 **전에** 이 값만 읽는다 (`AppPaths.resolve`).
    ///
    /// 저장소를 열려면 폴더를 알아야 하고, 폴더를 알려면 설정을 읽어야 한다.
    /// 그 고리를 여기서 끊는다 — 파생물 자리(Application Support)는 설정과
    /// 무관하게 언제나 같은 곳이므로 설정 파일은 늘 찾을 수 있다.
    public static func storedVault(inSupport support: URL) -> StoredVault? {
        let location = support.appending(path: "settings.json", directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: location),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              let path = settings.vaultPath,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return StoredVault(path: path, bookmark: settings.vaultBookmark)
    }

    public static func storedVaultPath(inSupport support: URL) -> String? {
        storedVault(inSupport: support)?.path
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
