import Foundation

/// 이 앱이 어떻게 깔려 있는가 — **누가 바꿔야 하는지**가 여기서 갈린다.
///
/// Homebrew 로 깔린 앱을 앱이 스스로 바꾸면 **brew 의 장부가 어긋난다.**
/// Caskroom 에는 옛 판이 적힌 채로 남아, 다음 `brew upgrade` 가 이미 새 판인
/// 자리를 다시 덮거나 checksum 이 안 맞는다고 멈춘다. 릴리스 워크플로가
/// «이미 나간 판의 바이트는 바꾸지 않는다» 를 지키는 것과 같은 종류의 규칙이다 —
/// 둘이 같은 것을 관리한다고 믿게 두면 안 된다.
public enum InstallSource: Sendable, Equatable {
    /// App Store가 업데이트를 관리한다. 외부 업데이트를 확인하거나 설치하지 않는다.
    case appStore
    /// brew 가 관리한다. 앱은 손대지 않고 사람에게 `brew upgrade` 를 알린다.
    case homebrew
    /// 앱이 스스로 바꾼다.
    case standalone
    /// `swift run` 으로 도는 중 — 바꿀 번들이 없다.
    case development

    static let caskrooms = [
        "/opt/homebrew/Caskroom/lazymemo",
        "/usr/local/Caskroom/lazymemo",
    ]

    /// cask 가 앱을 놓는 자리. `/Applications` 든 `~/Applications` 든 꼬리가 같다.
    static let caskDestination = "/Applications/LazyMemo.app"

    public static func detect(
        bundlePath: String,
        appStoreBuild: Bool = false,
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> InstallSource {
        guard bundlePath.hasSuffix(".app"), !bundlePath.contains("/.build/") else {
            return .development
        }
        if appStoreBuild || exists(bundlePath + "/Contents/_MASReceipt/receipt") {
            return .appStore
        }
        // 브루가 깔려 있다는 것만으로는 부족하다 — **이 번들이 brew 가 놓은
        // 자리에 있을 때**만 brew 의 것이다. 손으로 받아 다른 데 둔 앱까지
        // brew 에 미루면 그 사람은 영영 업데이트를 못 받는다.
        if bundlePath.hasSuffix(caskDestination), caskrooms.contains(where: exists) {
            return .homebrew
        }
        return .standalone
    }

    /// 지금 도는 이 앱. 한 번 보고 적어 둔다 — 업데이트·Claude 연동·메뉴가
    /// 전부 같은 답을 봐야 한다. 둘이 따로 판별하면 한쪽만 고쳐지는 날이 온다.
    ///
    /// App Store 판은 Info.plist 의 `LazyMemoAppStoreBuild` 가 말한다 — 영수증은
    /// 스토어가 깔아 준 뒤에야 생기므로, 로컬에서 지은 스토어 판을 시험할 때는
    /// 그 키가 유일한 근거다.
    public static let current: InstallSource = detect(
        bundlePath: Bundle.main.bundlePath,
        appStoreBuild: Bundle.main.object(forInfoDictionaryKey: "LazyMemoAppStoreBuild") as? Bool == true
    )

    /// App Store 판인가 — 샌드박스 안이고, 바깥 프로세스(`claude`)를 부를 수 없다.
    public var isAppStore: Bool { self == .appStore }

    /// 사람에게 하는 말. 앱이 스스로 못 바꾸는 경우에만 쓴다.
    public var advice: String? {
        switch self {
        case .appStore: "App Store에서 업데이트할 수 있습니다"
        case .homebrew: "brew upgrade --cask lazymemo"
        case .development, .standalone: nil
        }
    }

    public var allowsExternalUpdates: Bool { self == .homebrew || self == .standalone }
}
