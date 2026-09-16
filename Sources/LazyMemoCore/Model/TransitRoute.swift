import Foundation

/// 약속 자리까지 **가는 길 하나** — 비서가 찾아 메모에 적는 것 (`RouteNote`).
///
/// 길을 재는 것은 바깥이다 (`LazyMemoPlaces` 의 `TransitRouter`). 여기는 그 답을
/// 사람이 읽을 모양으로 들고 있을 뿐이라 MapKit 도, 네트워크도 모른다 — MCP 서버와
/// 시험이 같은 타입을 쓴다. 시각은 **도착 시각 하나**를 정본으로 두고 출발은 거기서
/// 뺀다: 약속 시각이 곧 도착 시각이고, 길이 바뀌면 출발만 움직인다.
public struct TransitRoute: Sendable, Equatable {
    /// 한 구간의 탈것.
    public enum Mode: String, Sendable, CaseIterable {
        case walk, bus, subway, taxi
        /// 애플 지도가 「대중교통 N분」만 알려 준 것 — 구간이 없다. 한국에서는 안 나온다.
        case transit
    }

    public struct Leg: Sendable, Equatable {
        public var mode: Mode
        public var minutes: Int
        /// 버스 번호(「3314」)·지하철 노선(「2호선」). 걷기·택시에는 없다.
        public var line: String?
        /// 버스의 종류(「지선」·「간선」·「마을」). 색과 이름표가 이것으로 갈린다.
        public var kind: String?
        /// 타는 정류장·역.
        public var from: String?
        /// 내리는 정류장·역.
        public var to: String?
        /// 지나는 정류장 수.
        public var stops: Int?
        /// 지하철의 방면(「강남 방면」).
        public var heading: String?
        /// 내릴 때의 출구 번호(「2」).
        public var exit: String?
        /// 택시의 예상 요금 — 길 전체의 `fare` 와 따로 두는 이유는 택시는 구간이 곧 길이라서다.
        public var fare: Int?
        /// 택시의 거리(m).
        public var distance: Int?
        /// 타는 시각 — 시간표를 아는 길(네이버)만 준다. 「18:12 승차」.
        public var boardAt: Date?

        public init(
            mode: Mode, minutes: Int, line: String? = nil, kind: String? = nil,
            from: String? = nil, to: String? = nil, stops: Int? = nil, heading: String? = nil,
            exit: String? = nil, fare: Int? = nil, distance: Int? = nil, boardAt: Date? = nil
        ) {
            self.mode = mode; self.minutes = max(0, minutes); self.line = line; self.kind = kind
            self.from = from; self.to = to; self.stops = stops; self.heading = heading
            self.exit = exit; self.fare = fare; self.distance = distance; self.boardAt = boardAt
        }

        /// 타는 구간인가 — 걷기는 아니다.
        public var rides: Bool { mode != .walk }
    }

    public var origin: String
    public var destination: String
    /// 전체 소요 시간(분).
    public var minutes: Int
    /// 도착해야 할 시각 — 약속 시각.
    public var arrive: Date
    /// 총 요금(원). 모르면 nil.
    public var fare: Int?
    public var legs: [Leg]
    /// 누가 잰 길인가(「naver」·「apple」). 파일에는 적지 않는다 — 다시 재 볼 때만 쓴다.
    public var provider: String?

    public init(origin: String, destination: String, minutes: Int, arrive: Date, fare: Int? = nil, legs: [Leg], provider: String? = nil) {
        self.origin = origin
        self.destination = destination
        self.minutes = max(0, minutes)
        self.arrive = arrive
        self.fare = fare
        self.legs = legs
        self.provider = provider
    }

    /// 출발할 시각 — 도착에서 소요 시간을 뺀 것.
    public var depart: Date { arrive.addingTimeInterval(-Double(minutes) * 60) }

    /// 걷는 시간의 합.
    public var walkMinutes: Int { legs.filter { $0.mode == .walk }.reduce(0) { $0 + $1.minutes } }

    /// 타는 구간들 — 카드의 줄이 되는 것.
    public var rides: [Leg] { legs.filter(\.rides) }

    /// 갈아타는 횟수 — 타는 구간이 둘이면 한 번.
    public var transfers: Int { max(0, rides.count - 1) }

    /// 이 길의 종류. 사람이 「버스로」「지하철로」 골라 낸 것이 이것이다.
    public enum Kind: String, Sendable, CaseIterable {
        case bus, subway, mixed, taxi, transit

        /// 사람의 말 — 되물음의 선택지와 카드의 머리글.
        public var label: String {
            switch self {
            case .bus: return "버스"
            case .subway: return "지하철"
            case .mixed: return "버스+지하철"
            case .taxi: return "택시"
            case .transit: return "대중교통"
            }
        }
    }

    public var kind: Kind {
        let modes = Set(rides.map(\.mode))
        if modes.contains(.taxi) { return .taxi }
        if modes.contains(.transit) { return .transit }
        switch (modes.contains(.bus), modes.contains(.subway)) {
        case (true, true): return .mixed
        case (true, false): return .bus
        case (false, true): return .subway
        case (false, false): return .transit
        }
    }

    /// 「버스 → 지하철」— 갈아타는 차례를 사람의 말로. 갈아타지 않으면 nil.
    public var transferWords: String? {
        guard transfers > 0 else { return nil }
        return rides.map { Self.word(for: $0.mode) }.joined(separator: " → ")
    }

    static func word(for mode: Mode) -> String {
        switch mode {
        case .walk: return "걷기"
        case .bus: return "버스"
        case .subway: return "지하철"
        case .taxi: return "택시"
        case .transit: return "대중교통"
        }
    }

    /// 「1,500원」.
    public static func won(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return (formatter.string(from: NSNumber(value: amount)) ?? String(amount)) + "원"
    }
}

/// 탈것의 색 — 네이버·서울시가 쓰는 색 그대로, 사람이 이미 아는 색이라 배울 것이 없다.
///
/// Core 는 SwiftUI 를 모르므로 hex 문자열로 둔다. 화면이 `Color` 로 바꾼다.
public enum TransitPalette {
    /// 버스의 종류별.
    public static func busHex(kind: String?) -> String {
        switch kind {
        case "간선", "급행간선", "간선급행": return "#3D5BAB"
        case "광역", "직행좌석", "급행": return "#E60012"
        case "순환": return "#F99D1C"
        case "공항": return "#78A3D1"
        case "마을": return "#5BB025"
        default: return "#53B332"
        }
    }

    /// 수도권 지하철 노선별. 모르는 노선은 회색.
    public static func subwayHex(line: String?) -> String {
        guard let line else { return "#8E8E93" }
        let table: [(String, String)] = [
            ("1호선", "#0052A4"), ("2호선", "#00A84D"), ("3호선", "#EF7C1C"), ("4호선", "#00A5DE"),
            ("5호선", "#996CAC"), ("6호선", "#CD7C2F"), ("7호선", "#747F00"), ("8호선", "#E6186C"),
            ("9호선", "#BDB092"), ("신분당", "#D4003B"), ("경의중앙", "#77C4A3"), ("경의", "#77C4A3"),
            ("공항철도", "#0090D2"), ("공항", "#0090D2"), ("수인분당", "#F5A200"), ("분당", "#F5A200"),
            ("경춘", "#0C8E72"), ("우이신설", "#B0CE18"), ("신림", "#6789CA"), ("서해", "#8FC31F"),
            ("김포골드", "#A17800"), ("의정부", "#FDA600"), ("용인에버", "#4EA346"), ("GTX", "#9A6292"),
            ("경강", "#003DA5"), ("인천1", "#7CA8D5"), ("인천2", "#ED8B00"), ("동해", "#0054A6"),
            ("부산1", "#F06A00"), ("부산2", "#81BF48"), ("부산3", "#BB8C00"), ("부산4", "#217DCB"),
            ("대구1", "#D93F5C"), ("대구2", "#00AA80"), ("대구3", "#FFB100"), ("대전1", "#007448"),
            ("광주1", "#009088"),
        ]
        return table.first { line.contains($0.0) }?.1 ?? "#8E8E93"
    }

    public static func hex(for leg: TransitRoute.Leg) -> String {
        switch leg.mode {
        case .bus: return busHex(kind: leg.kind)
        case .subway: return subwayHex(line: leg.line)
        case .taxi: return "#F2A900"
        case .transit: return "#3D5BAB"
        case .walk: return "#8E8E93"
        }
    }
}
