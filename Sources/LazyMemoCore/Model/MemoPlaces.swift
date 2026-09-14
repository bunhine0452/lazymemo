import Foundation

/// 메모 한 장에 적힌 **자리들** — 파일의 `place:` 하나와 본문에 남은 `@낱말` 들.
///
/// 메모의 장소 칸은 하나다 (`Memo.place`). 「@강남역에서 보고 @홍대입구로 이동」처럼
/// 자리가 여럿이면 첫째만 칸에 들어가고 나머지는 본문에 글로 남는다. 화면은 그
/// 전부를 카드로 세운다 — 칸에 든 것이 첫 장, 본문의 것이 그 뒤. 파일 규격은
/// 바뀌지 않는다: 자리를 늘리려고 새 칸을 만들면 Claude(MCP)·단축어·손으로 적는
/// 사람이 전부 새 규격을 배워야 한다.
public enum MemoPlaces {
    public struct Place: Sendable, Equatable, Identifiable {
        public var name: String
        /// 파일에 적힌 좌표. 첫 자리에만 있을 수 있다 — 본문의 자리는 이름뿐이다.
        public var geo: Coordinate?
        public var id: String { name }

        public init(name: String, geo: Coordinate? = nil) {
            self.name = name
            self.geo = geo
        }
    }

    /// 칸의 자리 먼저, 그다음 본문의 `@낱말` 차례대로. 같은 이름은 한 번만.
    public static func of(_ memo: Memo) -> [Place] {
        var places: [Place] = []
        if let name = memo.place?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            places.append(Place(name: name, geo: memo.geo))
        } else if let geo = memo.geo {
            places.append(Place(name: geo.description, geo: geo))
        }
        for found in PlaceParser.parseAll(memo.body) where !places.contains(where: { $0.name == found.place }) {
            places.append(Place(name: found.place))
        }
        return places
    }
}
