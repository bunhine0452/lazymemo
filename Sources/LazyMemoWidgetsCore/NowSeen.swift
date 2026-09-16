import Foundation
import LazyMemoCore

/// 「봤어요」로 내려놓은 것 — 이 기기의 기억이다.
///
/// 파일에 적지 않는다. 폰에서 본 것을 맥의 종이가 물러나야 할 이유는 없고, 알림
/// 설정이 기기별인 것과 같은 결이다. 어제 것은 다음에 적을 때 버린다 — 이름표가
/// 오늘보다 이르면 다시는 맞을 일이 없다.
///
/// 자리는 App Group 의 defaults 다 — **위젯이 같은 기억을 본다.** 앱에서 내려놓은 카드가
/// 홈 화면의 「지금」에는 그대로 서 있으면 두 화면이 다른 말을 한다. 폰의 「지금」 띠
/// (`NowBand`)와 위젯 확장이 같이 쓰려고 앱 밖 이 모듈에 둔다.
public enum NowSeen {
    private static let key = "now-seen"

    /// 앱과 위젯이 같이 보는 defaults. App Group 이 없는 빌드(맥)는 표준 defaults 로 떨어진다.
    /// `UserDefaults` 는 스스로 스레드 안전이라 계산 속성으로 매번 꺼내도 값은 하나다.
    public static var shared: UserDefaults { UserDefaults(suiteName: AppPaths.appGroupIdentifier) ?? .standard }

    public static func load(defaults: UserDefaults = shared) -> [ULID: Date] {
        guard let raw = defaults.dictionary(forKey: key) as? [String: Double] else { return [:] }
        var seen: [ULID: Date] = [:]
        for (id, seconds) in raw {
            guard let ulid = ULID(id) else { continue }
            seen[ulid] = Date(timeIntervalSince1970: seconds)
        }
        return seen
    }

    public static func save(
        _ seen: [ULID: Date], now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = shared
    ) {
        let today = calendar.startOfDay(for: now)
        var raw: [String: Double] = [:]
        for (id, stamp) in seen where stamp >= today {
            raw[id.description] = stamp.timeIntervalSince1970
        }
        defaults.set(raw, forKey: key)
    }
}
