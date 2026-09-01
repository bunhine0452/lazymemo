import Foundation

/// 적힌 그대로에서 읽어 낸 것.
public struct ParsedNote: Sendable, Equatable {
    public var body: String
    public var due: CalendarDate?
    public var at: Date?
    public var place: String?
    public var every: Recurrence?

    public init(
        body: String, due: CalendarDate? = nil, at: Date? = nil,
        place: String? = nil, every: Recurrence? = nil
    ) {
        self.body = body
        self.due = due
        self.at = at
        self.place = place
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
public enum NoteReader {
    public static func read(
        _ raw: String, place explicit: String? = nil, now: Date = Date()
    ) -> ParsedNote {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return ParsedNote(body: raw) }

        // 통째로 주소면 그대로 둔다 — 덜어내면 남는 것이 없다.
        if explicit == nil, let address = PlaceParser.address(text) {
            return ParsedNote(body: text, place: address)
        }

        var body = text
        var place = explicit

        if explicit == nil, let found = PlaceParser.parse(text) {
            place = found.place
            body = NaturalDateParser.strip(found.phrases, from: body)
        }

        guard let schedule = NaturalDateParser.parse(body, now: now) else {
            return ParsedNote(body: body, place: place)
        }
        let stripped = NaturalDateParser.strip(schedule.phrases, from: body)
        return ParsedNote(
            body: stripped.isEmpty ? body : stripped,
            due: schedule.due, at: schedule.at, place: place, every: schedule.every
        )
    }

    public static func read(_ note: InboundNote, now: Date = Date()) -> ParsedNote {
        read(note.text, place: note.place, now: now)
    }
}
