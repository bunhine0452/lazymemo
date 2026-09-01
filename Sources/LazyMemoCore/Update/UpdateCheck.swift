import Foundation

/// 나가 있는 가장 새 판.
public struct Release: Sendable, Equatable {
    public let version: SemanticVersion
    /// 앱 번들이 든 zip.
    public let download: URL
    /// 그 zip 의 sha256 이 적힌 자산. 없을 수도 있다 — 옛 판에는 안 올렸다.
    public let checksum: URL?
    /// 사람이 읽는 릴리스 쪽.
    public let notes: URL?

    public init(version: SemanticVersion, download: URL, checksum: URL? = nil, notes: URL? = nil) {
        self.version = version
        self.download = download
        self.checksum = checksum
        self.notes = notes
    }
}

/// 새 판이 나왔는지 GitHub 릴리스에 물어본다.
///
/// **여기서 네트워크 경로가 하나 더 생긴다.** §9.3 의 약속(기본 상태에서
/// 네트워크를 쓰지 않는다)은 링크 카드에서 한 번 갈렸고, 여기가 두 번째다.
/// 링크 카드에 걸었던 조건 셋을 그대로 건다.
///
/// 1. **설정으로 끌 수 있다** (`Settings.checksForUpdates`). 끄면 이 경로가 닫힌다.
/// 2. **나가는 것은 메모가 아니다.** 요청에 실리는 것은 주소 하나뿐이고 본문도
///    판 번호도 보내지 않는다 — 견주는 일은 받아온 뒤 이 기계 안에서 한다.
///    다만 GitHub 는 이 앱을 쓰는 IP 를 알게 되므로 README 에 그대로 적는다.
/// 3. **언제 물었는지가 보인다.** 메뉴가 마지막으로 확인한 때를 적는다.
///
/// 받아오는 함수를 밖에서 받는 이유는 시험 때문이다. 네트워크 없이 응답 모양만
/// 바꿔 가며 걸리는지 볼 수 있어야 한다 — 실제로 걸려야 하는 것은 «자산 이름이
/// 바뀌었다» 같은, 릴리스 워크플로를 고친 날 생기는 고장이다.
public enum UpdateCheck {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case unreadable
        case noVersion(String)
        case noAsset(String)

        public var description: String {
            switch self {
            case .unreadable: "릴리스 정보를 읽지 못했습니다"
            case .noVersion(let tag): "판 번호를 알 수 없는 태그입니다: \(tag)"
            case .noAsset(let version): "\(version) 릴리스에 내려받을 앱이 없습니다"
            }
        }
    }

    public static let feed = URL(
        string: "https://api.github.com/repos/bunhine0452/lazymemo/releases/latest"
    )!

    public static func latest(fetch: Fetch) async throws -> Release {
        try release(from: try await fetch(feed))
    }

    /// 새 판이면 그것을, 아니면 `nil`. **같은 판은 새 판이 아니다.**
    public static func newer(than current: SemanticVersion, in release: Release) -> Release? {
        release.version > current ? release : nil
    }

    static func release(from data: Data) throws -> Release {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String
        else { throw Failure.unreadable }

        guard let version = SemanticVersion(tag) else { throw Failure.noVersion(tag) }

        let assets = object["assets"] as? [[String: Any]] ?? []
        func url(named suffix: String) -> URL? {
            for asset in assets {
                guard let name = asset["name"] as? String,
                      name.hasPrefix("lazymemo-"), name.hasSuffix(suffix),
                      let raw = asset["browser_download_url"] as? String,
                      let url = URL(string: raw)
                else { continue }
                return url
            }
            return nil
        }

        guard let download = url(named: ".zip") else { throw Failure.noAsset(version.description) }

        return Release(
            version: version,
            download: download,
            checksum: url(named: ".zip.sha256"),
            notes: (object["html_url"] as? String).flatMap(URL.init(string:))
        )
    }
}
