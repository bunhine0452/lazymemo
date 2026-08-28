import Foundation

/// 붙여넣은 링크에 붙일 이름.
///
/// **네트워크를 쓰지 않는다.** 페이지를 열어 제목을 가져오면 보기에는 좋지만,
/// "기본 상태에서 lazymemo 는 네트워크를 쓰지 않는다"(설계문서 §9.3)는 약속이
/// 그 순간 깨진다. 메모를 적는 것만으로 바깥에 요청이 나가서는 안 된다.
///
/// 그래서 주소 자체에서 읽어낼 수 있는 것만 쓴다. 대개 그것으로 충분하다 —
/// 사람은 `github.com/lazymemo` 만 봐도 무엇인지 안다.
public enum LinkLabel {
    public static func short(for url: URL) -> String {
        let host = (url.host() ?? url.absoluteString)
            .replacingOccurrences(of: "www.", with: "")

        let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let last = components.last else { return host }

        // 파일 이름이면 확장자를 떼고, 슬러그면 하이픈을 띄어쓰기로 편다.
        let readable = last
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let trimmed = readable.count > 40 ? String(readable.prefix(40)) + "…" : readable

        return "\(host)/\(trimmed)"
    }

    /// 본문에 넣을 마크다운.
    public static func markdown(for url: URL) -> String {
        "[\(short(for: url))](\(url.absoluteString))"
    }
}
