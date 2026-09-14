import Foundation

/// 적힌 그대로에서 읽어 낸 것.
public struct ParsedNote: Sendable, Equatable {
    public var body: String
    public var due: CalendarDate?
    public var at: Date?
    public var place: String?
    /// 지도 주소에 적혀 있던 좌표. 이름과 달리 글에서는 읽지 않는다 — 좌표를 손으로
    /// 적는 사람은 없고, 있어야 「가면 떠오르기」가 그 자리를 안다.
    public var geo: Coordinate?
    public var every: Recurrence?

    public init(
        body: String, due: CalendarDate? = nil, at: Date? = nil,
        place: String? = nil, geo: Coordinate? = nil, every: Recurrence? = nil
    ) {
        self.body = body
        self.due = due
        self.at = at
        self.place = place
        self.geo = geo
        self.every = every
    }
}

/// 사람이 적은 그대로에서 **날짜와 장소를 읽어 낸다.**
///
/// **문이 몇이든 읽는 규칙은 하나다.** 빠른 입력·클립보드·URL 스킴·CLI·단축어가
/// 저마다 다르게 읽으면, 같은 글을 어디에 붙였느냐에 따라 결과가 달라진다 —
/// 그건 사용자가 «형식을 배우지 않는다» 는 약속을 문마다 다시 배우는 것이다.
///
/// 장소를 먼저 덜어내고 날짜를 읽는다. `@강남역` 이 붙은 채로 날짜 파서에
/// 들어가면 낱말표가 엉뚱한 것을 집을 수 있다.
///
/// 장소의 출처는 넷이고 **사람이 가까운 순서**로 믿는다 — 밖에서 준 것(단축어의
/// 「현재 위치」) → 손으로 찍은 `@강남역` → 지도 앱이 공유한 이름·주소 → 지도
/// 주소에 적힌 검색어. 좌표는 지도 주소에서만 나오고, 밖에서 장소를 준 경우에는
/// 읽지 않는다 — 그 이름과 이 좌표가 다른 곳일 수 있어서다.
public enum NoteReader {
    public static func read(
        _ raw: String, place explicit: String? = nil, now: Date = Date()
    ) -> ParsedNote {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return ParsedNote(body: raw) }

        let spot = explicit == nil ? MapLink.spot(in: text) : nil

        // 통째로 주소면 그대로 둔다 — 덜어내면 남는 것이 없다.
        if explicit == nil, let address = PlaceParser.address(text) {
            return ParsedNote(body: text, place: address, geo: spot?.geo)
        }
        // 지도 앱이 공유한 이름·주소·링크도 그대로 둔다 — 이름이 곧 제목이다.
        if explicit == nil, let shared = PlaceParser.share(text) {
            return ParsedNote(body: shared.body, place: shared.place, geo: spot?.geo)
        }

        var body = text
        var place = explicit

        if explicit == nil, let found = PlaceParser.parse(text) {
            place = found.place
            body = NaturalDateParser.strip(found.phrases, from: body)
        }
        if place == nil { place = spot?.place }

        guard let schedule = NaturalDateParser.parse(body, now: now) else {
            return ParsedNote(body: body, place: place, geo: spot?.geo)
        }
        let stripped = NaturalDateParser.strip(schedule.phrases, from: body)
        return ParsedNote(
            body: stripped.isEmpty ? body : stripped,
            due: schedule.due, at: schedule.at, place: place, geo: spot?.geo, every: schedule.every
        )
    }

    public static func read(_ note: InboundNote, now: Date = Date()) -> ParsedNote {
        read(note.text, place: note.place, now: now)
    }
}
