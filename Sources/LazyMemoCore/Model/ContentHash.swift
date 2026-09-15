import CryptoKit
import Foundation

extension Memo {
    /// 본문의 SHA-256 — 변경 직전 「내가 본 그 글인가」를 대조하는 버전 토큰.
    ///
    /// `updated` 는 초 단위라 같은 초 안의 두 저장을 가르지 못하고, 다른 기기가
    /// 옛 `updated` 를 들고 올 수도 있다. 본문 hash 는 글이 같으면 같고 다르면 다르다.
    public var contentHash: String { Self.contentHash(of: body) }

    public static func contentHash(of body: String) -> String {
        SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
