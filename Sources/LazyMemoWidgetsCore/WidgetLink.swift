import Foundation
import LazyMemoCore

/// 위젯이 앱을 두드리는 주소 — `lazymemo://memo/<ULID>` 는 그 메모를, `lazymemo://write` 는 펜을.
///
/// 스킴은 맥의 `lazymemo://add?text=…`(`InboundLink`)와 같다. 동사가 다를 뿐이라 한 스킴을
/// 나눠 쓰고, 여기서는 **위젯이 쓰는 두 동사만** 읽는다 — 모르는 주소는 `nil` 로 돌려
/// 부르는 쪽이 `InboundLink` 에 넘기게 한다.
public enum WidgetLink {
    public static let scheme = InboundLink.scheme

    public enum Destination: Equatable, Sendable {
        /// 그 메모를 연다.
        case memo(ULID)
        /// 펜을 올린다 — 폰은 글 칸에 포커스, 맥은 빠른 입력 상자.
        case write
    }

    private static let memoVerb = "memo"
    private static let writeVerb = "write"

    public static func memo(_ id: ULID) -> URL {
        URL(string: "\(scheme)://\(memoVerb)/\(id.description)")!
    }

    public static let write = URL(string: "\(scheme)://\(writeVerb)")!

    /// 위젯의 두 동사만 읽는다. `lazymemo://memo/<id>` 는 host 가 동사, path 가 id 다.
    public static func destination(of url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        // `lazymemo://write` 는 host 로, `lazymemo:write` 는 path 로 들어온다 (InboundLink 와 같다).
        let pieces = ((parts.host.map { [$0] } ?? []) + parts.path.split(separator: "/").map(String.init))
            .filter { !$0.isEmpty }
        guard let verb = pieces.first?.lowercased() else { return nil }
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
}
