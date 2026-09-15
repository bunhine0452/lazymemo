import Foundation
import LazyMemoCore

/// 모델 출력을 계약 타입으로 옮기며 검증한다. 통과 못 하면 nil — 저장 쪽으로 아무것도 흘리지 않는다.
enum OutputValidator {
    static func jsonObject(_ text: String) -> [String: Any]? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().joined(separator: "\n")
            if let r = s.range(of: "```", options: .backwards) { s = String(s[..<r.lowerBound]) }
        }
        guard let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}"), open < close,
              let data = s[open...close].data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    /// 모델이 앞에 `id:` 를 붙이는 버릇이 있다. 허용 목록과 대조하기 전에 걷어낸다.
    static func memoID(_ raw: Any?) -> ULID? {
        guard var s = raw as? String else { return nil }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("id:") { s = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        return ULID(s)
    }

    /// 근거 id 는 보여 준 것만. 없는 id 는 버리고, 다 버려지면 답도 버린다.
    static func answer(_ text: String, allowed: Set<ULID>) -> AssistantAnswer? {
        guard let obj = jsonObject(text) else { return nil }
        let found = obj["found"] as? Bool ?? false
        let answer = (obj["answer"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cited = ((obj["evidence"] as? [Any]) ?? []).compactMap(memoID).filter(allowed.contains)
        if found && cited.isEmpty { return AssistantAnswer(found: false, text: "", evidence: []) }
        return AssistantAnswer(found: found, text: answer, evidence: cited)
    }

    static func brief(_ text: String, allowed: [Evidence], limit: Int = 3) -> [BriefItem]? {
        guard let obj = jsonObject(text), let items = obj["items"] as? [[String: Any]] else { return nil }
        let eligible = Set(allowed.filter { $0.state == .active }.map(\.memoID))
        var seen = Set<ULID>()
        var out: [BriefItem] = []
        for item in items {
            guard let id = memoID(item["memoID"]), eligible.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            out.append(BriefItem(memoID: id, reason: (item["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)))
            if out.count == limit { break }
        }
        return out
    }

    /// 명세 §5 — allowlist·명시 필드만·「이거」는 열린 메모만·대상 불명은 ask 로.
    static func action(_ text: String, request: AssistantRequest, evidence: [Evidence]) -> ProposedAction? {
        guard let obj = jsonObject(text), let kindRaw = obj["kind"] as? String else { return nil }
        guard let kind = ActionKind(rawValue: kindRaw) else { return nil }
        let question = (obj["question"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPatch = obj["patch"] as? [String: Any] ?? [:]

        switch kind {
        case .ask:
            return ProposedAction(requestID: request.id, kind: .ask, question: question?.isEmpty == false ? question : nil)
        case .none:
            return ProposedAction(requestID: request.id, kind: .none)
        case .createMemo:
            guard let patch = fieldPatch(rawPatch, timeZone: request.timeZone), let body = patch.body, !body.isEmpty else { return nil }
            return ProposedAction(requestID: request.id, kind: .createMemo, patch: patch)
        case .setRecall, .reschedule, .moveToFolder, .trash:
            // 대상은 보여 준 메모 중 하나여야 하고, 열린 메모가 있으면 그것이어야 한다.
            guard let target = memoID(obj["memoID"]), let ev = evidence.first(where: { $0.memoID == target }) else {
                return ProposedAction(requestID: request.id, kind: .ask, question: "어느 메모를 말하는지 알려 주세요")
            }
            if let selected = request.selectedMemoID, selected != target {
                return ProposedAction(requestID: request.id, kind: .ask, question: "열린 메모가 아닌 다른 메모를 바꿀까요?")
            }
            guard var patch = fieldPatch(rawPatch, timeZone: request.timeZone) else { return nil }
            patch = narrowed(patch, to: kind)
            if kind != .trash && patch.isEmpty { return nil }
            return ProposedAction(requestID: request.id, kind: kind, memoID: target, expectedContentHash: ev.contentHash, patch: patch)
        }
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

    /// 없는 키는 keep, 빈 문자열은 clear, 값은 파싱. 파싱이 안 되면 통째로 실패 — 절반만 적지 않는다.
    static func fieldPatch(_ raw: [String: Any], timeZone: TimeZone) -> FieldPatch? {
        var patch = FieldPatch()
        if let body = raw["body"] as? String { patch.body = body }
        if let v = raw["folder"] as? String { patch.folder = v.isEmpty ? .clear : .set(v) }
        if let v = raw["due"] as? String {
            if v.isEmpty { patch.due = .clear }
            else if let d = calendarDate(v, timeZone: timeZone) { patch.due = .set(d) }
            else { return nil }
        }
        for (key, keyPath) in [("at", \FieldPatch.at), ("surface", \FieldPatch.surface)] {
            guard let v = raw[key] as? String else { continue }
            if v.isEmpty { patch[keyPath: keyPath] = .clear }
            else if let d = date(v) { patch[keyPath: keyPath] = .set(d) }
            else { return nil }
        }
        return patch
    }

    static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        for opts in [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]] as [ISO8601DateFormatter.Options] {
            f.formatOptions = opts
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    static func calendarDate(_ s: String, timeZone: TimeZone) -> CalendarDate? {
        let parts = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        if parts.count == 3 { return CalendarDate(year: parts[0], month: parts[1], day: parts[2]) }
        // 모델이 due 에 시각까지 적었으면 그 날로 받는다.
        guard let d = date(s) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return CalendarDate(d, calendar: cal)
    }
}
