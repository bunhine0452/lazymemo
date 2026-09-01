import Foundation

/// 이 앱이 어떻게 깔려 있는가 — **누가 바꿔야 하는지**가 여기서 갈린다.
///
/// Homebrew 로 깔린 앱을 앱이 스스로 바꾸면 **brew 의 장부가 어긋난다.**
/// Caskroom 에는 옛 판이 적힌 채로 남아, 다음 `brew upgrade` 가 이미 새 판인
/// 자리를 다시 덮거나 checksum 이 안 맞는다고 멈춘다. 릴리스 워크플로가
/// «이미 나간 판의 바이트는 바꾸지 않는다» 를 지키는 것과 같은 종류의 규칙이다 —
/// 둘이 같은 것을 관리한다고 믿게 두면 안 된다.
public enum InstallSource: Sendable, Equatable {
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
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> InstallSource {
        guard bundlePath.hasSuffix(".app"), !bundlePath.contains("/.build/") else {
            return .development
        }
        // 브루가 깔려 있다는 것만으로는 부족하다 — **이 번들이 brew 가 놓은
        // 자리에 있을 때**만 brew 의 것이다. 손으로 받아 다른 데 둔 앱까지
        // brew 에 미루면 그 사람은 영영 업데이트를 못 받는다.
        if bundlePath.hasSuffix(caskDestination), caskrooms.contains(where: exists) {
            return .homebrew
        }
        return .standalone
    }

    /// 사람에게 하는 말. 앱이 스스로 못 바꾸는 경우에만 쓴다.
    public var advice: String? {
        switch self {
        case .homebrew: "brew upgrade --cask lazymemo"
        case .development, .standalone: nil
        }
    }
}
