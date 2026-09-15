import Foundation
import LazyMemoCore

/// 모델이 낸 명령 초안 — 검증 전. 무엇 하나 그대로 믿지 않는다.
struct RawCommand {
    var kind: String?
    var memoID: ULID?
    var folder: String?
    var body: String?
    var question: String?
}

/// 명세 §5 를 코드로. 모델은 「무엇을」 제안하고, **언제·어느 메모·정말 그 뜻인가는 앱이 정한다.**
///
/// 2B 모델은 「금요일 오전 10시」를 날짜로 옮기다 틀리고, 메모 본문의 지시에 끌려간다(벤치 2026-09-15).
/// 그래서 시각은 앱의 파서(`NaturalDateParser`)가, 동사는 사용자의 말(`verbs`)이, 대상은 열린 메모만이 정한다.
/// 셋 중 하나라도 비면 실행하지 않고 **한 가지만 묻는다**.
enum CommandResolver {
    enum Resolved: Equatable { case moment(Date), day(CalendarDate) }

    static let questions = (
        noTarget: "어느 메모를 말하는지 골라 주세요",
        when: "언제로 할까요? 예: 「금요일 오전 10시」",
        timeOfDay: "몇 시에 알릴까요?",
        folder: "어느 폴더로 옮길까요?",
        unsupported: "무엇을 할지 한 가지만 알려 주세요 — 다시 보기·일정·폴더·새 메모·휴지통",
        bulk: "한 번에 여러 메모를 지우지는 않습니다. 한 장씩 골라 주세요",
        body: "새 메모에 무엇을 적을까요?"
    )

    // MARK: 낱말표

    static let verbs: [(ActionKind, [String])] = [
        (.setRecall, ["알려줘", "알려 줘", "알려주", "알림", "띄워", "띄우", "다시보여", "다시 보여", "다시보기", "다시 보기", "리마인드", "상기시"]),
        (.trash, ["지워", "지우", "삭제", "휴지통", "버려", "없애"]),
        (.moveToFolder, ["폴더"]),
        (.createMemo, ["메모 만들", "메모만들", "메모 추가", "메모추가", "메모 남겨", "메모남겨", "메모해", "메모 해", "새 메모", "새메모", "적어", "기록해", "만들어", "추가해"]),
        (.reschedule, ["미뤄", "미루", "옮겨", "옮기", "바꿔", "바꾸", "변경", "당겨", "연기"]),
    ]
    static let abortWords = ["아무것도 하지", "아무것도하지", "하지 마", "하지마", "그만둬", "그만해", "관둬", "안 해도", "안해도"]
    static let recallWords = ["다시 보", "다시보", "알림", "리마인드"]
    static let clearWords = ["취소", "해제", "꺼", "지워", "빼"]
    static let bulkWords = ["전부", "모두", "모든", "싹", "다 지워", "다지워", "다 삭제"]
    /// 날이 정해지지 않는 말. 앱의 파서는 「주말」을 토요일로 읽지만, 비서는 묻는다.
    static let vagueWords = ["주말", "나중", "이따", "언젠가", "곧", "조만간", "적당히", "알아서", "며칠"]
    static let numberWords: [String: Int] = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10]

    static func mentions(_ words: [String], in text: String) -> Bool {
        let squeezed = text.replacingOccurrences(of: " ", with: "")
        return words.contains { text.contains($0) || squeezed.contains($0.replacingOccurrences(of: " ", with: "")) }
    }

    static func verbs(in text: String) -> Set<ActionKind> {
        Set(verbs.filter { mentions($0.1, in: text) }.map(\.0))
    }

    static func normalizeKind(_ raw: String?, folder: String?, body: String?) -> ActionKind? {
        guard let raw else { return nil }
        switch raw.lowercased().replacingOccurrences(of: "_", with: "") {
        case "setrecall", "surface", "recall", "remind", "reminder": return .setRecall
        case "reschedule", "schedule", "movedate", "date", "time": return .reschedule
        case "movetofolder", "move", "folder": return .moveToFolder
        case "creatememo", "create", "new", "add", "memo": return .createMemo
        case "trash", "delete", "remove": return .trash
        case "ask", "question", "clarify": return .ask
        case "none", "noop", "cancel", "nothing": return ActionKind.none
        case "patch", "update", "edit", "modify", "set":
            if folder != nil { return .moveToFolder }
            if body != nil { return .createMemo }
            return nil
        default: return nil
        }
    }

    // MARK: 시각

    /// 사용자의 말에서 시각을 앱이 읽는다. 모델이 적은 날짜는 보지 않는다.
    static func resolveTime(_ text: String, anchor: Schedule?, now: Date, calendar: Calendar) -> Resolved? {
        if mentions(vagueWords, in: text) { return nil }
        if let relative = relative(text, anchor: anchor, calendar: calendar) { return relative }
        if let weekDay = weekDay(text, now: now, calendar: calendar) { return weekDay }
        if let monthDay = monthDay(text, now: now, calendar: calendar) { return .day(monthDay) }
        if let parsed = NaturalDateParser.parse(text, now: now, calendar: calendar) {
            if let at = parsed.at { return .moment(at) }
            if let due = parsed.due { return .day(due) }
        }
        if let day = bareDayOfMonth(text, now: now, calendar: calendar) { return .day(day) }
        return nil
    }

    /// 「한 시간 전」「전날 아침 9시」「30일 전」 — 열린 메모의 일정을 기준으로.
    static func relative(_ text: String, anchor: Schedule?, calendar: Calendar) -> Resolved? {
        guard let anchor, !anchor.isEmpty else { return nil }
        let pattern = #"(\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|반)\s*(시간|분|일|주)\s*(전|앞|뒤|후|있다가)"#
        var offsetSeconds: TimeInterval?
        var offsetDays: Int?
        if let m = firstMatch(pattern, in: text) {
            let count = Double(m[1]).flatMap { $0 } ?? (m[1] == "반" ? 0.5 : Double(numberWords[m[1]] ?? 0))
            let sign: Double = ["전", "앞"].contains(m[3]) ? -1 : 1
            switch m[2] {
            case "시간": offsetSeconds = sign * count * 3600
            case "분": offsetSeconds = sign * count * 60
            case "일": offsetDays = Int(sign * count)
            case "주": offsetDays = Int(sign * count * 7)
            default: break
            }
        } else if mentions(["전날", "전 날", "하루 전", "하루전"], in: text) {
            offsetDays = -1
        } else if mentions(["이틀 전", "이틀전"], in: text) {
            offsetDays = -2
        } else if mentions(["당일", "그날", "그 날"], in: text) {
            offsetDays = 0
        }
        if let offsetSeconds {
            guard let at = anchor.at else { return nil }
            return .moment(at.addingTimeInterval(offsetSeconds))
        }
        guard let offsetDays else { return nil }
        let baseDay: CalendarDate? = anchor.due ?? anchor.at.map { CalendarDate($0, calendar: calendar) }
        guard let baseDay, let baseMidnight = baseDay.startOfDay(calendar: calendar),
              let day = calendar.date(byAdding: .day, value: offsetDays, to: baseMidnight) else { return nil }
        if let time = NaturalDateParser.timeOfDay(in: text),
           let moment = calendar.date(byAdding: DateComponents(hour: time.hour, minute: time.minute), to: day) {
            return .moment(moment)
        }
        if let at = anchor.at {
            let clock = calendar.dateComponents([.hour, .minute], from: at)
            if let moment = calendar.date(byAdding: DateComponents(hour: clock.hour, minute: clock.minute), to: day) {
                return .moment(moment)
            }
        }
        return .day(CalendarDate(day, calendar: calendar))
    }

    /// 「다음 주 월요일」 — 그 주의 월요일. 앱의 파서는 「다음에 오는 월요일 + 7일」로 읽어(화요일에 말하면 13일 뒤)
    /// 사람의 말(「다음 주」= 다음 주간)과 어긋난다. 비서는 주간으로 센다. 시각이 붙어 있으면 그 시각.
    static func weekDay(_ text: String, now: Date, calendar: Calendar) -> Resolved? {
        guard let m = firstMatch(#"(다다음\s?주|다음\s?주|담주|이번\s?주|지난\s?주)\s*(월|화|수|목|금|토|일)요일"#, in: text) else { return nil }
        let shift = m[1].hasPrefix("다다음") ? 2 : m[1].hasPrefix("이번") ? 0 : m[1].hasPrefix("지난") ? -1 : 1
        let weekdays = ["월": 0, "화": 1, "수": 2, "목": 3, "금": 4, "토": 5, "일": 6]
        guard let offset = weekdays[m[2]] else { return nil }
        var cal = calendar
        cal.firstWeekday = 2
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let day = cal.date(byAdding: .day, value: shift * 7 + offset, to: weekStart) else { return nil }
        if let time = NaturalDateParser.timeOfDay(in: text),
           let moment = cal.date(byAdding: DateComponents(hour: time.hour, minute: time.minute), to: day) {
            return .moment(moment)
        }
        return .day(CalendarDate(day, calendar: cal))
    }

    /// 「다음 달 5일」 — 파서는 「다음 달」만 읽고 1일로 떨어진다.
    static func monthDay(_ text: String, now: Date, calendar: Calendar) -> CalendarDate? {
        guard let m = firstMatch(#"(다다음\s?달|다음\s?달|담달|이번\s?달)\s*(\d{1,2})\s*일"#, in: text), let day = Int(m[2]) else { return nil }
        let shift = m[1].hasPrefix("다다음") ? 2 : m[1].hasPrefix("이번") ? 0 : 1
        guard let shifted = calendar.date(byAdding: .month, value: shift, to: now) else { return nil }
        let comps = calendar.dateComponents([.year, .month], from: shifted)
        return CalendarDate(year: comps.year!, month: comps.month!, day: day)
    }

    /// 「20일로 미뤄」 — 달 이름 없는 날. 오늘 이후의 가장 가까운 그 날.
    static func bareDayOfMonth(_ text: String, now: Date, calendar: Calendar) -> CalendarDate? {
        guard let m = firstMatch(#"(?<![0-9월\d])(\d{1,2})\s*일(?=\s*(?:로|으로|에|까지|부터|$|\s))"#, in: text),
              let day = Int(m[1]), (1...31).contains(day) else { return nil }
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var month = today.month!, year = today.year!
        if day < today.day! { month += 1; if month > 12 { month = 1; year += 1 } }
        return CalendarDate(year: year, month: month, day: day)
    }

    /// 동사 없이 「…8시로」 — 시각 뒤의 로/으로 가 옮기라는 뜻이다.
    static func timeWithDirection(_ text: String) -> Bool {
        firstMatch(#"(시|분|반|일|주|달|요일|모레|내일|오늘|글피)\s*(으로|로)(?:$|[\s,.!?])"#, in: text) != nil
    }

    // MARK: 폴더·본문

    static func folder(in text: String, model: String?) -> FieldChange<String>? {
        if let model = model?.trimmingCharacters(in: .whitespaces), !model.isEmpty, text.contains(model) { return .set(model) }
        if let m = firstMatch(#"(\S+)\s*폴더(?:으로|로|에)(?!서)"#, in: text), !m[1].isEmpty, m[1] != "이거", m[1] != "이" {
            return .set(m[1])
        }
        if mentions(["폴더에서 빼", "폴더에서 꺼내", "폴더 밖", "폴더 없이", "폴더 빼"], in: text) { return .clear }
        return nil
    }

    static func body(text: String, model: String?, phrases: [String]) -> String {
        var body = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if body.isEmpty { body = text }
        body = NaturalDateParser.strip(phrases, from: body)
        let cruft = [#"^(이거|이것|이건)\s*"#,
                     #"\s*(새\s?)?메모(를|로)?\s*(만들어\s*줘?|추가(해\s*줘?)?|남겨\s*줘?|해\s*줘?|적어\s*줘?|하나\s*(만들어|추가)\s*줘?)?\s*[.!]?$"#,
                     #"\s*(적어\s*줘?|기록해\s*줘?|만들어\s*줘?|추가해\s*줘?)\s*[.!]?$"#]
        for pattern in cruft {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                body = regex.stringByReplacingMatches(in: body, range: NSRange(body.startIndex..., in: body), withTemplate: "")
            }
        }
        return body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",.!")))
    }

    // MARK: 해석

    static func resolve(_ raw: RawCommand?, request: AssistantRequest, selected: Evidence?, candidates: [Evidence]) -> ProposedAction? {
        let text = request.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone
        calendar.locale = request.locale
        let now = request.now
        func ask(_ q: String, candidates: [Evidence] = []) -> ProposedAction {
            ProposedAction(requestID: request.id, kind: .ask, question: q, candidates: candidates.map(\.memoID))
        }

        if mentions(abortWords, in: text) { return ProposedAction(requestID: request.id, kind: .none) }

        let said = verbs(in: text)
        let recallClear = mentions(recallWords, in: text) && mentions(clearWords, in: text)
        let modelKind = normalizeKind(raw?.kind, folder: raw?.folder, body: raw?.body)
        let hasDate = resolveTime(text, anchor: selected?.schedule, now: now, calendar: calendar) != nil

        let intended: ActionKind?
        if recallClear { intended = .setRecall }
        else if said.count == 1 { intended = said.first }
        else if let modelKind, said.contains(modelKind) { intended = modelKind }
        else if !said.isEmpty { intended = [.setRecall, .trash, .moveToFolder, .reschedule, .createMemo].first(where: said.contains) }
        else if text.contains("메모"), hasDate { intended = .createMemo }
        else if hasDate, timeWithDirection(text) { intended = .reschedule }
        else if modelKind == .ask || modelKind == ActionKind.none { intended = modelKind }
        else if raw == nil { return nil }
        else { intended = nil }

        guard let intended else { return ask(unsupportedQuestion(raw)) }
        switch intended {
        case .none: return ProposedAction(requestID: request.id, kind: .none)
        case .ask: return ask(modelQuestion(raw) ?? questions.unsupported, candidates: selected == nil ? candidates : [])
        case .createMemo:
            let parsed = NaturalDateParser.parse(text, now: now, calendar: calendar)
            let body = body(text: text, model: raw?.body, phrases: parsed?.phrases ?? [])
            guard !body.isEmpty else { return ask(questions.body) }
            var patch = FieldPatch(body: body)
            if let at = parsed?.at { patch.at = .set(at) } else if let due = parsed?.due { patch.due = .set(due) }
            return ProposedAction(requestID: request.id, kind: .createMemo, patch: patch)
        case .trash, .setRecall, .reschedule, .moveToFolder:
            if intended == .trash, mentions(bulkWords, in: text) { return ask(questions.bulk) }
            guard let target = selected else { return ask(questions.noTarget, candidates: candidates) }
            let patch: FieldPatch
            switch intended {
            case .trash:
                patch = FieldPatch()
            case .setRecall:
                if recallClear { patch = FieldPatch(surface: .clear); break }
                switch resolveTime(text, anchor: target.schedule, now: now, calendar: calendar) {
                case .moment(let date): patch = FieldPatch(surface: .set(date))
                case .day: return ask(questions.timeOfDay)
                case nil: return ask(questions.when)
                }
            case .reschedule:
                switch resolveTime(text, anchor: target.schedule, now: now, calendar: calendar) {
                case .moment(let date): patch = FieldPatch(at: .set(date))
                case .day(let day): patch = FieldPatch(due: .set(day))
                case nil: return ask(questions.when)
                }
            default:
                guard let change = folder(in: text, model: raw?.folder) else { return ask(questions.folder) }
                patch = FieldPatch(folder: change)
            }
            return ProposedAction(requestID: request.id, kind: intended, memoID: target.memoID,
                                  expectedContentHash: target.contentHash, patch: patch)
        }
    }

    static func unsupportedQuestion(_ raw: RawCommand?) -> String {
        guard raw?.kind?.lowercased() == "ask" else { return questions.unsupported }
        return modelQuestion(raw) ?? questions.unsupported
    }

    /// 모델의 되물음은 물음표로 끝나는 진짜 질문일 때만 쓴다 — 지시문의 낱말(「모르겠다」)을 그대로 옮겨 적는 일이 있다.
    static func modelQuestion(_ raw: RawCommand?) -> String? {
        guard let q = raw?.question?.trimmingCharacters(in: .whitespacesAndNewlines), q.count >= 4, q.count <= 60,
              q.hasSuffix("?") || q.hasSuffix("요") else { return nil }
        return q
    }

    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: text) else { return "" }
            return String(text[r])
        }
    }
}
