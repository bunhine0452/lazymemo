import Foundation

/// 장소를 **시스템 지도**에 넘기는 주소를 만든다.
///
/// 이 앱은 지도를 그리지 않는다. 앱 안에 지도 뷰를 두면 재질이 둘이 되고
/// (§14.5 「재질은 하나 — 종이」), 종이 위에 지도를 얹는 순간 화면이 «글자와
/// 종이뿐»(철학 4)이 아니게 된다. 그래서 장소는 종이에 찍힌 잉크 자국 하나이고,
/// 누르면 지도는 **바깥에서** 열린다.
///
/// **여기서 만드는 것은 주소 문자열뿐이고, 이 타입은 아무 데도 접속하지 않는다.**
/// 실제로 여는 것은 사용자가 눌렀을 때의 OS 다 — §9.3 의 약속(기본 상태에서
/// 네트워크를 쓰지 않는다)이 장소를 들여도 그대로다.
public enum MapLink {
    /// 좌표가 있으면 그 점으로, 없으면 이름을 검색어로 넘긴다.
    ///
    /// `ll` 만 넘기면 지도는 그 자리를 보여주되 핀에 이름이 없다. `q` 를 늘
    /// 함께 넘겨 **무엇을 찾아간 것인지가 지도에도 남게** 한다.
    public static func url(place: String?, geo: Coordinate?) -> URL? {
        let name = place.flatMap { $0.isEmpty ? nil : $0 } ?? geo?.description
        guard let name else { return nil }

        var items: [URLQueryItem] = []
        if let geo { items.append(URLQueryItem(name: "ll", value: geo.description)) }
        items.append(URLQueryItem(name: "q", value: name))

        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = items
        return components?.url
    }

    public static func url(for memo: Memo) -> URL? {
        url(place: memo.place, geo: memo.geo)
    }
}
