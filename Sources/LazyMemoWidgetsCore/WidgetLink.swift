import Foundation
import LazyMemoCore

/// 위젯이 앱을 두드리는 주소 — `lazymemo://memo/<ULID>` 는 그 메모를, `lazymemo://write` 는 펜을,
/// `lazymemo://calendar[/2026-09-17]` 은 달력(그 날)을.
///
/// 스킴은 맥의 `lazymemo://add?text=…`(`InboundLink`)와 같다. 동사가 다를 뿐이라 한 스킴을
/// 나눠 쓰고, 여기서는 **위젯이 쓰는 동사만** 읽는다 — 모르는 주소는 `nil` 로 돌려
/// 부르는 쪽이 `InboundLink` 에 넘기게 한다.
///
/// 달력 동사는 `Destination` 에 넣지 않았다 — 앱 둘(`AppModel.open`·`AppDelegate`)이 그 열거를
/// `default` 없이 가르고 있어 갈래가 늘면 둘이 함께 바뀌어야 한다. 달력 위젯이 먼저 서고 앱은
/// `calendarStop(of:)` 로 뒤따른다; 그때까지 그 주소는 앱을 여는 것으로 그친다 (모르는 주소는
/// 조용히 버려진다).
public enum WidgetLink {
    public static let scheme = InboundLink.scheme

    public enum Destination: Equatable, Sendable {
        /// 그 메모를 연다.
        case memo(ULID)
        /// 펜을 올린다 — 폰은 글 칸에 포커스, 맥은 빠른 입력 상자.
        case write
    }

    /// 달력의 어디로 — 이번 달, 또는 그 날.
    public enum CalendarStop: Equatable, Sendable {
        case month
        case day(CalendarDate)
    }

    private static let memoVerb = "memo"
    private static let writeVerb = "write"
    private static let calendarVerb = "calendar"

    public static func memo(_ id: ULID) -> URL {
        URL(string: "\(scheme)://\(memoVerb)/\(id.description)")!
    }

    public static let write = URL(string: "\(scheme)://\(writeVerb)")!

    /// 달력을 연다. 날을 주면 그 날로 — `lazymemo://calendar/2026-09-17`.
    public static func calendar(_ day: CalendarDate? = nil) -> URL {
        URL(string: "\(scheme)://\(calendarVerb)" + (day.map { "/\($0.description)" } ?? ""))!
    }

    /// 달력 주소만 읽는다. 날이 깨졌으면(`2026-9-1`) 주소 전체를 모르는 것으로 친다 —
    /// 엉뚱한 달을 여는 것보다 아무것도 안 하는 편이 낫다.
    public static func calendarStop(of url: URL) -> CalendarStop? {
        guard let pieces = verbPieces(of: url), pieces.first?.lowercased() == calendarVerb else { return nil }
        switch pieces.count {
        case 1: return .month
        case 2: return CalendarDate(iso: pieces[1]).map { .day($0) }
        default: return nil
        }
    }

    /// 위젯의 두 동사만 읽는다. `lazymemo://memo/<id>` 는 host 가 동사, path 가 id 다.
    public static func destination(of url: URL) -> Destination? {
        guard let pieces = verbPieces(of: url), let verb = pieces.first?.lowercased() else { return nil }
        switch verb {
        case writeVerb:
            return .write
        case memoVerb:
            guard pieces.count == 2, let id = ULID(pieces[1]) else { return nil }
            return .memo(id)
        default:
            return nil
        }
    }

    /// 동사와 그 뒤의 조각들. `lazymemo://write` 는 host 로, `lazymemo:write` 는 path 로 들어온다
    /// (InboundLink 와 같다). 우리 스킴이 아니면 nil.
    private static func verbPieces(of url: URL) -> [String]? {
        guard url.scheme?.lowercased() == scheme,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let pieces = ((parts.host.map { [$0] } ?? []) + parts.path.split(separator: "/").map(String.init))
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? nil : pieces
    }
}
