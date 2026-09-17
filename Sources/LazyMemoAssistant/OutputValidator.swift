import Foundation
import LazyMemoCore

/// 모델 출력을 계약 타입으로 옮기며 검증한다. 통과 못 하면 nil — 저장 쪽으로 아무것도 흘리지 않는다.
enum OutputValidator {
    /// 첫 `{` 부터 짝이 맞는 `}` 까지 — 코드펜스·앞뒤 말·뒤에 붙은 둘째 객체를 걷어낸다.
    static func jsonObject(_ text: String) -> [String: Any]? {
        guard let open = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = open
        while index < text.endIndex {
            let ch = text[index]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else if ch == "\"" { inString = true }
            else if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let slice = text[open...index]
                    guard let data = slice.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                    return obj
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// 모델이 `id:`·`메모 ` 를 앞에 붙이거나 `{"id": …}` 로 감싸는 버릇이 있다. 허용 목록과 대조하기 전에 걷어낸다.
    static func memoID(_ raw: Any?) -> ULID? {
        if let dict = raw as? [String: Any] { return memoID(dict["id"] ?? dict["memoID"] ?? dict["memo_id"]) }
        guard let s = raw as? String else { return nil }
        if let direct = ULID(s.trimmingCharacters(in: .whitespaces)) { return direct }
        guard let regex = try? NSRegularExpression(pattern: "[0-9A-HJKMNP-TV-Z]{26}"),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range, in: s) else { return nil }
        return ULID(String(s[r]))
    }

    static func memoIDs(_ raw: Any?) -> [ULID] {
        var out: [ULID] = []
        for item in (raw as? [Any]) ?? [raw as Any] {
            if let id = memoID(item), !out.contains(id) { out.append(id) }
        }
        return out
    }

    static let negations = ["없습니다", "없어요", "없다", "찾을 수 없", "모르겠", "않습니다", "확인할 수 없", "정보가 없", "언급이 없", "나와 있지 않"]

    /// 근거 id 는 보여 준 것만. 없는 id 는 버리고, 답에 근거가 하나도 남지 않으면 「찾지 못함」이다.
    ///
    /// 그 위에 앱이 두 가지를 더한다 — ① 인용한 메모의 원문 줄을 답 밑에 세운다(모델의 한 문장이 모자라도 사람이 본다),
    /// ② 모델이 못 찾았다 해도 질문의 개념을 둘 이상 담은 메모가 있으면 그 메모를 답으로 보여 준다(2B 모델은 여섯 장 중
    /// 하나를 자주 놓친다 — 벤치 2026-09-15). 인용은 질문과 낱말이 하나도 안 겹치면 믿지 않는다(지어낸 근거).
    static func answer(_ text: String, allowed: [Evidence], question: String) -> AssistantAnswer? {
        guard let obj = jsonObject(text) else { return nil }
        // 근거가 웹이면 낱말만 다르다 — 「검색 결과에서 이 부분을 찾았어요」, 그리고 답 밑에 출처 링크.
        let web = allowed.contains(where: \.isWeb)
        let foundHere = web ? "검색 결과에서 이 부분을 찾았어요" : "메모에서 이 부분을 찾았어요"
        let flag = obj["found"] as? Bool ?? true
        var answer = (obj["answer"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if ["found", "true", "false", "answer", ":", "-"].contains(answer.lowercased()) { answer = "" }
        let denies = negations.contains { answer.contains($0) }
        let concepts = QueryTerms.concepts(question)
        let hits = Dictionary(uniqueKeysWithValues: allowed.map { ($0.memoID, QueryTerms.conceptHits(concepts, in: $0.excerpt)) })
        let allowedIDs = Set(allowed.map(\.memoID))
        var cited = memoIDs(obj["evidence"]).filter(allowedIDs.contains)
        if cited.isEmpty, flag, !denies, !answer.isEmpty { cited = attribute(answer, to: allowed) }
        if !concepts.isEmpty { cited = cited.filter { (hits[$0] ?? 0) >= 1 } }

        let best = hits.values.max() ?? 0
        let top = allowed.filter { hits[$0.memoID] == best }
        // 제약 디코딩 아래서 모델이 answer 를 비우거나 「: 」만 적고 근거는 맞게 대는 일이 있다(벤치 A04·A07·A14).
        // 근거를 맞게 댔으면 그 원문이 답이다.
        if answer.isEmpty, !cited.isEmpty, !(flag == false && denies) {
            let picked = cited.prefix(2).compactMap { id in allowed.first { $0.memoID == id } }
            return AssistantAnswer(found: true, text: foundHere, evidence: picked.map(\.memoID), quotes: picked.map(quote), sources: picked.compactMap(source))
        }
        if answer.isEmpty || cited.isEmpty || (!flag && denies) {
            // 모델은 못 찾았다. 질문의 개념을 둘 이상 담은 메모가 있으면 그 원문이 답이다.
            guard best >= 2, let first = top.first else { return AssistantAnswer(found: false, text: "", evidence: []) }
            let picked = Array(top.prefix(2))
            return AssistantAnswer(found: true, text: foundHere, evidence: picked.map(\.memoID), quotes: picked.map(quote), sources: picked.compactMap(source))
        }
        // 인용한 메모와 같은 만큼 질문에 맞는 다른 메모가 있으면 함께 보여 준다 — 근거가 갈리면 확정하지 않는다(명세 §4).
        var evidence = Array(cited.prefix(2))
        if best >= 1, let rival = top.first(where: { !evidence.contains($0.memoID) }),
           evidence.contains(where: { hits[$0] == best }), evidence.count < 2 {
            evidence.append(rival.memoID)
        }
        let picked = evidence.compactMap { id in allowed.first { $0.memoID == id } }
        return AssistantAnswer(found: true, text: answer, evidence: evidence, quotes: picked.map(quote), sources: picked.compactMap(source))
    }

    /// 웹 근거의 링크. 메모면 nil.
    static func source(_ e: Evidence) -> WebSource? {
        guard let url = e.url else { return nil }
        return WebSource(id: e.memoID, title: e.title ?? url.host() ?? url.absoluteString, url: url)
    }

    /// 모델 없이 — 검색 결과 앞의 셋을 그대로 보여 준다. 답 문장은 없고 출처와 발췌만.
    static func plainWebAnswer(_ hits: [Evidence], limit: Int = 3) -> AssistantAnswer {
        let picked = Array(hits.prefix(limit))
        return AssistantAnswer(found: !picked.isEmpty, text: "", evidence: picked.map(\.memoID), quotes: picked.map(quote), sources: picked.compactMap(source))
    }

    /// 답의 낱말이 가장 많이 겹치는 근거 메모. 「개인 사실을 단정하는 문장에는 근거가 있어야 한다」(명세 §4).
    static func attribute(_ answer: String, to allowed: [Evidence]) -> [ULID] {
        let terms = QueryTerms.extract(answer).filter { $0.weight >= 0.9 }.map(\.text)
        guard !terms.isEmpty else { return [] }
        let scored = allowed.map { e -> (ULID, Int) in
            let hay = e.excerpt.lowercased()
            return (e.memoID, terms.filter { hay.contains($0) }.count)
        }
        guard let best = scored.map(\.1).max(), best > 0 else { return [] }
        return scored.filter { $0.1 == best }.map(\.0)
    }

    /// 메모 원문의 앞 네 줄, 200자까지 — 「비번: …」은 셋째 줄에 있기도 하다.
    static func quote(_ e: Evidence) -> String {
        let lines = e.excerpt.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return String(lines.prefix(4).joined(separator: " · ").prefix(200))
    }

    /// 근거만·최대 셋·완료/휴지통 제외. **시각이 정해진 오늘 메모는 모델이 빠뜨려도 앞에 세운다.**
    static func brief(_ text: String, allowed: [Evidence], request: AssistantRequest, limit: Int = 3) -> [BriefItem]? {
        // 출력 상한(192 토큰)에 잘린 JSON 이면 온전한 항목만 건진다 — 브리핑은 셋이면 되니까.
        guard let items = (jsonObject(text)?["items"] as? [[String: Any]]) ?? salvageItems(text) else { return nil }
        let eligible = allowed.filter { $0.state == .active }
        let eligibleIDs = Set(eligible.map(\.memoID))
        var picked: [BriefItem] = []
        for item in items {
            guard let id = memoID(item["memoID"] ?? item["id"]), eligibleIDs.contains(id), !picked.contains(where: { $0.memoID == id }) else { continue }
            picked.append(BriefItem(memoID: id, reason: (item["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone
        let today = CalendarDate(request.now, calendar: calendar)
        let timed = eligible
            .compactMap { e -> (Evidence, Date)? in
                guard let at = e.schedule.at, CalendarDate(at, calendar: calendar) == today else { return nil }
                return (e, at)
            }
            .sorted { $0.1 < $1.1 }
        var out: [BriefItem] = []
        for (e, at) in timed.prefix(limit) {
            let reason = picked.first { $0.memoID == e.memoID }?.reason
            let clock = DateFormatter()
            clock.timeZone = request.timeZone
            clock.locale = request.locale
            clock.dateStyle = .none
            clock.timeStyle = .short
            out.append(BriefItem(memoID: e.memoID, reason: reason?.isEmpty == false ? reason! : "오늘 \(clock.string(from: at))"))
        }
        for item in picked where !out.contains(where: { $0.memoID == item.memoID }) && out.count < limit { out.append(item) }
        return Array(out.prefix(limit))
    }

    /// `{"items": [{…}, {…}, {"memoID": "…", "rea` 처럼 잘린 글에서 닫힌 `{…}` 만 꺼낸다.
    static func salvageItems(_ text: String) -> [[String: Any]]? {
        guard let start = text.range(of: "\"items\"")?.upperBound,
              let regex = try? NSRegularExpression(pattern: #"\{[^{}]*\}"#) else { return nil }
        let tail = String(text[start...])
        let items = regex.matches(in: tail, range: NSRange(tail.startIndex..., in: tail)).compactMap { m -> [String: Any]? in
            guard let r = Range(m.range, in: tail), let data = tail[r].data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        return items.isEmpty ? nil : items
    }

    /// 명세 §5 — 모델의 초안을 `CommandResolver` 에 넘긴다. 날짜·대상·동사는 거기서 앱이 정한다.
    static func action(_ text: String?, request: AssistantRequest, selected: Evidence?, candidates: [Evidence]) -> ProposedAction? {
        var raw: RawCommand?
        if let text, let obj = jsonObject(text) {
            let patch = obj["patch"] as? [String: Any] ?? [:]
            raw = RawCommand(
                kind: obj["kind"] as? String,
                memoID: memoID(obj["memoID"] ?? obj["memo_id"] ?? obj["id"]),
                folder: (patch["folder"] as? String) ?? (obj["folder"] as? String),
                body: (patch["body"] as? String) ?? (obj["body"] as? String),
                question: obj["question"] as? String)
        }
        return CommandResolver.resolve(raw, request: request, selected: selected, candidates: candidates)
    }

    /// kind 가 허락하는 필드만 남긴다 — 「다시 알려줘」가 `at` 을 바꾸지 않게.
    static func narrowed(_ p: FieldPatch, to kind: ActionKind) -> FieldPatch {
        switch kind {
        case .setRecall: return FieldPatch(surface: p.surface)
        case .reschedule: return FieldPatch(due: p.due, at: p.at)
        case .moveToFolder: return FieldPatch(folder: p.folder)
        case .createMemo: return p
        case .trash, .ask, .none: return FieldPatch()
        }
    }

    static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        for opts in [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]] as [ISO8601DateFormatter.Options] {
            f.formatOptions = opts
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
