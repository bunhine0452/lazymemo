import Foundation

/// 메모의 **생김새**. 낱말이 기억나지 않을 때 남는 단서다.
///
/// "그 링크 뭐였지", "사진 붙여 둔 거" — 게으른 사람이 실제로 기억하는 것은
/// 본문이 아니라 이런 것이다. 본문 검색만 있으면 그 기억으로는 아무 데도
/// 갈 수 없다.
public enum MemoShape: Sendable, Equatable, CaseIterable {
    case photo, link, checklist

    public var label: String {
        switch self {
        case .photo: "사진"
        case .link: "링크"
        case .checklist: "체크"
        }
    }

    public static func named(_ word: String) -> MemoShape? {
        allCases.first { $0.label == word }
    }

    public func matches(_ memo: Memo) -> Bool {
        switch self {
        case .photo: !MarkdownScanner.imagePaths(in: memo.body).isEmpty
        case .link: !MarkdownScanner.linkDestinations(in: memo.body).isEmpty
        case .checklist: !MarkdownScanner.checkboxes(in: memo.body).isEmpty
        }
    }
}

/// 빠른 입력 상자에 친 글에서 **거를 조건**을 읽는다.
///
/// **새 문법을 만들지 않았다.** 이미 이 앱이 쓰는 기호를 그대로 쓴다 —
/// `#` 은 태그와 생김새(`#사진`·`#링크`·`#체크`), `@` 는 장소, 날짜는
/// **치는 순간 이미 칩으로 떠오르는 그것**이다. 배울 것이 하나도 없어야
/// "게으른 찾기" 이고, 기억나지 않는 낱말 대신 기호를 외우게 하면
/// 본문 검색보다 나을 것이 없다.
///
/// 날짜를 쓰는 방식이 여기서 갈린다 — **적힌 날이든 손댄 날이든** 걸린다.
/// 「어제」라고 친 사람이 찾는 것은 어제로 잡아 둔 일정일 수도, 어제 적어
/// 둔 메모일 수도 있고, 어느 쪽인지 묻지 않는 편이 게으르다.
public struct MemoFilter: Sendable, Equatable {
    /// 조건을 뺀 나머지. 인덱스에 넘길 검색어다.
    public var words: String
    public var shapes: [MemoShape]
    public var tags: [String]
    public var place: String?
    public var day: CalendarDate?

    public init(
        words: String = "", shapes: [MemoShape] = [], tags: [String] = [],
        place: String? = nil, day: CalendarDate? = nil
    ) {
        self.words = words
        self.shapes = shapes
        self.tags = tags
        self.place = place
        self.day = day
    }

    /// 거를 것이 하나라도 있는가.
    public var narrows: Bool {
        !shapes.isEmpty || !tags.isEmpty || place != nil || day != nil
    }

    /// 사람에게 보여 줄 짧은 말들. **가려진 것은 가려진 줄도 모른다.**
    public var chips: [String] {
        shapes.map { "#" + $0.label }
            + tags.map { "#" + $0 }
            + (place.map { ["@" + $0] } ?? [])
    }

    public static func read(
        _ query: String, now: Date = Date(), calendar: Calendar = .current
    ) -> MemoFilter {
        var filter = MemoFilter()
        var rest = query

        for token in marked(in: query, sigil: "#") {
            if let shape = MemoShape.named(token.word) {
                filter.shapes.append(shape)
            } else {
                filter.tags.append(token.word)
            }
            rest = NaturalDateParser.strip([token.phrase], from: rest)
        }

        if let found = PlaceParser.parse(rest) {
            filter.place = found.place
            rest = NaturalDateParser.strip(found.phrases, from: rest)
        }

        // 날짜는 **이미 칩으로 떠 있는 그것**이다. 따로 읽지 않는다.
        if let schedule = NaturalDateParser.parse(rest, now: now, calendar: calendar) {
            filter.day = schedule.due ?? schedule.at.map { CalendarDate($0, calendar: calendar) }
            rest = NaturalDateParser.strip(schedule.phrases, from: rest)
        }

        // 조건을 걷어내고 아무것도 안 남으면 검색어는 없는 것이다 —
        // `strip` 은 비면 원문을 돌려주므로 여기서 갈라 본다.
        filter.words = filter.narrows && rest == query ? "" : rest
        return filter
    }

    public func matches(_ memo: Memo, calendar: Calendar = .current) -> Bool {
        guard shapes.allSatisfy({ $0.matches(memo) }) else { return false }
        guard tags.allSatisfy({ tag in memo.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } })
        else { return false }

        if let place {
            guard memo.place?.localizedCaseInsensitiveContains(place) ?? false else { return false }
        }
        if let day {
            let scheduled = memo.scheduledDate(calendar: calendar)
            let touched = CalendarDate(memo.updated, calendar: calendar)
            guard scheduled == day || touched == day else { return false }
        }
        return true
    }

    /// `#낱말`·`@낱말` 을 찾는다. **앞이 글의 처음이거나 공백일 때만** —
    /// `foo#bar` 는 조건이 아니다 (`PlaceParser` 가 메일 주소를 거르는 것과 같다).
    private static func marked(
        in text: String, sigil: Character
    ) -> [(word: String, phrase: String)] {
        var found: [(String, String)] = []
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            guard characters[index] == sigil,
                  index == 0 || characters[index - 1].isWhitespace
            else {
                index += 1
                continue
            }
            var end = index + 1
            while end < characters.count, !characters[end].isWhitespace { end += 1 }

            let raw = String(characters[(index + 1)..<end])
            var word = raw
            while let last = word.last, last.isPunctuation || last.isSymbol { word.removeLast() }
            if word.contains(where: { $0.isLetter || $0.isNumber }) {
                found.append((word, String(sigil) + raw))
            }
            index = end
        }
        return found
    }
}
