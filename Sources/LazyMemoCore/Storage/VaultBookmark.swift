import Foundation

#if os(macOS)
/// 샌드박스 밖의 폴더에 다시 닿는 열쇠 — App Store 판을 위한 것이다.
///
/// 샌드박스 안의 앱은 자기 컨테이너와 iCloud 컨테이너 밖을 못 본다. 사용자가
/// 패널로 고른 폴더는 **그 실행 동안만** 열리고, 다음 실행에 경로 문자열로
/// 다시 열면 문이 잠겨 있다 — 메모 폴더가 「없어진 것」으로 보인다. 그래서
/// 고른 순간 security-scoped bookmark 를 만들어 설정에 같이 적고, 뜰 때는
/// 그것으로 문을 연다.
///
/// 샌드박스 밖 판(GitHub·Homebrew)에서도 같은 코드가 돈다 — 열쇠가 없어도
/// 경로로 열리므로 해가 없고, 두 판이 같은 설정 파일 모양을 가진다.
public enum VaultBookmark {
    /// 문을 연 결과. 열쇠가 낡아 새로 만들었으면 그것도 들고 나온다 — 부른
    /// 쪽이 설정에 도로 적어야 다음 실행에 또 만들지 않는다.
    public struct Access: Sendable, Equatable {
        public let url: URL
        public let refreshed: Data?
    }

    /// 열쇠를 만든다. 못 만들면 `nil` — 샌드박스 밖에서는 없어도 열린다.
    public static func make(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// 열쇠로 문을 연다. **닫지 않는다** — 메모 폴더는 앱이 사는 동안 내내
    /// 필요하고, `startAccessingSecurityScopedResource` 는 프로세스가 끝나면
    /// 저절로 풀린다.
    ///
    /// 열쇠가 낡았으면(폴더가 옮겨졌거나 이름이 바뀌었거나) 새 열쇠를 같이
    /// 돌려준다. 폴더가 아예 없어졌으면 `nil`.
    public static func open(_ data: Data) -> Access? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return Access(url: url, refreshed: stale ? make(for: url) : nil)
    }
}
#endif
