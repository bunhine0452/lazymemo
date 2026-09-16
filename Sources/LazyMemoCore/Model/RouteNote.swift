import Foundation

/// 가는 길을 메모 본문에 **사람이 읽는 마크다운**으로 적고, 도로 읽는다.
///
/// 정본은 마크다운이다 (D4). 길을 별도 파일이나 frontmatter 에 JSON 으로 넣으면
/// Claude(MCP)·텍스트 에디터·아이폰의 맨 글 칸에서 읽을 수 없는 덩어리가 생긴다.
/// 그래서 사람이 그대로 읽어도 뜻이 서는 절 하나를 본문 끝에 둔다 —
///
/// ```
/// ## 가는 길
/// 석촌고분역 → 투파인드피터 잠실점 · 21분 · 18:09 출발 · 18:30 도착 · 1,500원 · 환승 1회
/// - 걷기 2분
/// - 버스 3314 (지선) 잠실여고후문 → 잠실역.롯데월드 · 8분 · 4정류장
/// - 지하철 2호선 잠실 → 강남 · 12분 · 6정거장 · 강남 방면 · 2번 출구로 · 18:20 승차
/// - 걷기 4분
/// ```
///
/// 카드(`RouteCard`)는 이 절을 읽어 그린다. 사람이 손으로 고쳐 모양이 어긋나면 카드가
/// 안 설 뿐 글은 그대로다 — 틀린 카드를 세우는 것보다 안 세우는 편이 낫다.
public enum RouteNote {
    public static let heading = "## 가는 길"

    // MARK: 적기

    /// 본문 끝에 절을 붙인다. 이미 있으면 갈아 끼운다 — 한 메모에 길은 하나다.
    public static func append(_ route: TransitRoute, to body: String, calendar: Calendar = .current) -> String {
        let stripped = remove(from: body)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = render(route, calendar: calendar)
        return trimmed.isEmpty ? section : trimmed + "\n\n" + section
    }

    /// 절을 뗀 본문. 없으면 그대로.
    public static func remove(from body: String) -> String {
        guard let range = sectionRange(in: body) else { return body }
        var result = body
        result.removeSubrange(range)
        // 절이 본문 끝이었으면 앞에 남은 빈 줄도 거둔다 — 끝에 빈 줄이 남으면 종이가 늘어져 보인다.
        if range.upperBound == body.endIndex {
            while let last = result.last, last == "\n" || last == " " { result.removeLast() }
        }
        return result
    }

    public static func render(_ route: TransitRoute, calendar: Calendar = .current) -> String {
        var lines = [heading, summary(route, calendar: calendar)]
        for leg in route.legs { lines.append("- " + render(leg, calendar: calendar)) }
        return lines.joined(separator: "\n")
    }

    static func summary(_ route: TransitRoute, calendar: Calendar) -> String {
        var parts = ["\(route.origin) → \(route.destination)", "\(route.minutes)분",
                     "\(clock(route.depart, calendar: calendar)) 출발", "\(clock(route.arrive, calendar: calendar)) 도착"]
        if let fare = route.fare { parts.append(TransitRoute.won(fare)) }
        if route.transfers > 0 { parts.append("환승 \(route.transfers)회") }
        return parts.joined(separator: separator)
    }

    static func render(_ leg: TransitRoute.Leg, calendar: Calendar = .current) -> String {
        switch leg.mode {
        case .walk:
            return "걷기 \(leg.minutes)분"
        case .bus, .subway:
            var head = TransitRoute.word(for: leg.mode)
            if let line = leg.line { head += " " + line }
            if leg.mode == .bus, let kind = leg.kind { head += " (\(kind))" }
            if let from = leg.from, let to = leg.to { head += " \(from) → \(to)" }
            var parts = [head, "\(leg.minutes)분"]
            if let stops = leg.stops { parts.append("\(stops)" + (leg.mode == .bus ? "정류장" : "정거장")) }
            if let heading = leg.heading { parts.append(heading.hasSuffix("방면") ? heading : heading + " 방면") }
            if let exit = leg.exit { parts.append("\(exit)번 출구로") }
            if let boardAt = leg.boardAt { parts.append("\(clock(boardAt, calendar: calendar)) 승차") }
            return parts.joined(separator: separator)
        case .taxi:
            var parts = ["택시 \(leg.minutes)분"]
            if let fare = leg.fare { parts.append("약 " + TransitRoute.won(fare)) }
            if let distance = leg.distance { parts.append(km(distance)) }
            return parts.joined(separator: separator)
        case .transit:
            return ["대중교통 \(leg.minutes)분", "자세한 길은 지도 앱에서"].joined(separator: separator)
        }
    }

    // MARK: 읽기

    /// 본문의 절을 읽는다. 절이 없거나 모양이 어긋나면 nil.
    ///
    /// - Parameter day: 시각의 날. 절에는 시·분만 적히므로 약속의 날(`Memo.at`)을 받아 채운다.
    public static func read(_ body: String, day: Date, calendar: Calendar = .current) -> TransitRoute? {
        guard let range = sectionRange(in: body) else { return nil }
        let lines = body[range].split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count >= 2, lines[0].trimmingCharacters(in: .whitespaces) == heading else { return nil }
        guard let head = readSummary(lines[1], day: day, calendar: calendar) else { return nil }

        var legs: [TransitRoute.Leg] = []
        for line in lines.dropFirst(2) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") else { break }
            guard let leg = readLeg(String(trimmed.dropFirst(2)), day: day, calendar: calendar) else { return nil }
            legs.append(leg)
        }
        guard !legs.isEmpty else { return nil }
        return TransitRoute(origin: head.origin, destination: head.destination, minutes: head.minutes,
                            arrive: head.arrive, fare: head.fare, legs: legs)
    }

    /// 본문에 절이 있는가.
    public static func contains(_ body: String) -> Bool { sectionRange(in: body) != nil }

    private static func readSummary(_ line: String, day: Date, calendar: Calendar)
        -> (origin: String, destination: String, minutes: Int, arrive: Date, fare: Int?)? {
        let parts = line.split(separator: separator, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let arrow = parts[0].range(of: arrow) else { return nil }
        let origin = String(parts[0][..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
        let destination = String(parts[0][arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !origin.isEmpty, !destination.isEmpty else { return nil }

        var minutes: Int?
        var arrive: Date?
        var fare: Int?
        for part in parts.dropFirst() {
            if minutes == nil, let value = number(before: "분", in: part), part.hasSuffix("분") { minutes = value }
            else if part.hasSuffix("도착"), let moment = time(String(part.dropLast(2)), day: day, calendar: calendar) { arrive = moment }
            else if part.hasSuffix("원"), let value = won(part) { fare = value }
        }
        guard let minutes, let arrive else { return nil }
        return (origin, destination, minutes, arrive, fare)
    }

    static func readLeg(_ line: String, day: Date = Date(), calendar: Calendar = .current) -> TransitRoute.Leg? {
        let parts = line.split(separator: separator, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let head = parts.first, !head.isEmpty else { return nil }

        if head.hasPrefix("걷기") {
            guard let minutes = number(before: "분", in: head) else { return nil }
            return TransitRoute.Leg(mode: .walk, minutes: minutes)
        }
        if head.hasPrefix("택시") {
            guard let minutes = number(before: "분", in: head) else { return nil }
            var leg = TransitRoute.Leg(mode: .taxi, minutes: minutes)
            for part in parts.dropFirst() {
                if part.hasSuffix("원") { leg.fare = won(part) }
                else if part.hasSuffix("km"), let value = Double(part.dropLast(2).trimmingCharacters(in: .whitespaces)) {
                    leg.distance = Int((value * 1000).rounded())
                }
            }
            return leg
        }
        if head.hasPrefix("대중교통") {
            guard let minutes = number(before: "분", in: head) else { return nil }
            return TransitRoute.Leg(mode: .transit, minutes: minutes)
        }

        let mode: TransitRoute.Mode
        if head.hasPrefix("버스 ") { mode = .bus } else if head.hasPrefix("지하철 ") { mode = .subway } else { return nil }
        var rest = String(head.drop(while: { !$0.isWhitespace })).trimmingCharacters(in: .whitespaces)
        var leg = TransitRoute.Leg(mode: mode, minutes: 0)

        // 「3314 (지선) 잠실여고문 → 잠실역」— 번호 · (종류) · 타는 곳 → 내리는 곳.
        let lineToken = String(rest.prefix(while: { !$0.isWhitespace }))
        guard !lineToken.isEmpty else { return nil }
        leg.line = lineToken
        rest = String(rest.dropFirst(lineToken.count)).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("("), let close = rest.firstIndex(of: ")") {
            leg.kind = String(rest[rest.index(after: rest.startIndex)..<close])
            rest = String(rest[rest.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        if let arrow = rest.range(of: arrow) {
            leg.from = String(rest[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
            leg.to = String(rest[arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var minutes: Int?
        for part in parts.dropFirst() {
            if part.hasSuffix("정류장") || part.hasSuffix("정거장") {
                leg.stops = number(before: part.hasSuffix("정류장") ? "정류장" : "정거장", in: part)
            } else if part.hasSuffix("번 출구로") {
                leg.exit = String(part.dropLast(5))
            } else if part.hasSuffix("방면") {
                leg.heading = part
            } else if part.hasSuffix("승차") {
                leg.boardAt = time(String(part.dropLast(2)), day: day, calendar: calendar)
            } else if minutes == nil, part.hasSuffix("분") {
                minutes = number(before: "분", in: part)
            }
        }
        guard let minutes else { return nil }
        leg.minutes = minutes
        return leg
    }

    // MARK: 절의 자리

    /// `## 가는 길` 줄부터 이어지는 요약·`- ` 줄까지, 그리고 그 뒤에 붙은 빈 줄들.
    ///
    /// 뒤의 빈 줄을 절에 넣는 이유는 떼어 냈을 때 앞뒤 글이 원래 간격으로 만나게 하려는 것이다 —
    /// 절이 본문 끝이면 `remove` 가 끝의 빈 줄도 거둔다.
    static func sectionRange(in body: String) -> Range<String.Index>? {
        // 줄마다 (시작, 줄바꿈 포함 끝) 을 잰다.
        var lines: [(text: Substring, start: String.Index, end: String.Index)] = []
        var cursor = body.startIndex
        while cursor < body.endIndex {
            let lineEnd = body[cursor...].firstIndex(of: "\n") ?? body.endIndex
            let next = lineEnd < body.endIndex ? body.index(after: lineEnd) : body.endIndex
            lines.append((body[cursor..<lineEnd], cursor, next))
            cursor = next
        }
        guard let head = lines.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespaces) == heading }) else { return nil }

        var last = head
        var index = head + 1
        while index < lines.count {
            let text = lines[index].text.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { break }
            // 요약 줄 하나 뒤로는 `- ` 줄만 절이다.
            if index > head + 1, !text.hasPrefix("- ") { break }
            last = index
            index += 1
        }
        var end = lines[last].end
        while index < lines.count, lines[index].text.trimmingCharacters(in: .whitespaces).isEmpty {
            end = lines[index].end
            index += 1
        }
        return lines[head].start..<end
    }

    // MARK: 조각

    static let separator = " · "
    static let arrow = " → "

    /// 「18:09」— 절과 카드가 같은 꼴을 쓴다.
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func time(_ raw: String, day: Date, calendar: Calendar) -> Date? {
        let pieces = raw.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard pieces.count == 2, let hour = Int(pieces[0]), let minute = Int(pieces[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: start)
    }

    /// 「4정류장」·「21분」— 접미사 앞의 숫자.
    private static func number(before suffix: String, in text: String) -> Int? {
        guard text.hasSuffix(suffix) else { return nil }
        let digits = text.dropLast(suffix.count).reversed().prefix(while: \.isNumber).reversed()
        return Int(String(digits))
    }

    /// 「1,500원」·「약 9,000원」.
    private static func won(_ text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func km(_ meters: Int) -> String {
        let value = Double(meters) / 1000
        return value >= 10 ? String(format: "%.0fkm", value) : String(format: "%.1fkm", value)
    }
}
