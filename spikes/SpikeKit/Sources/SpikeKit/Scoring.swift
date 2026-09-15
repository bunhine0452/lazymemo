import Foundation

/// 한 문항의 채점 결과. 이유는 사람이 읽고 반박할 수 있게 남긴다.
public struct QuestionResult: Sendable {
    public var id: String
    public var kind: QuestionKind
    public var passed: Bool
    public var reasons: [String]
    public var output: String
    public var stats: GenerationStats
    public var inputTokens: Int?
    public var repaired: Bool
}

/// 모델 출력에서 JSON 한 덩이를 꺼낸다. 코드펜스·앞뒤 말은 걷어낸다.
public enum JSONExtract {
    public static func object(from text: String) -> [String: Any]? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().joined(separator: "\n")
            if let r = s.range(of: "```", options: .backwards) { s = String(s[..<r.lowerBound]) }
        }
        guard let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}"), open < close else { return nil }
        let slice = String(s[open...close])
        guard let data = slice.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }
}

public enum Scoring {
    /// 부분 실패도 이유를 전부 모은다 — 게이트는 종류별로 따로 승격하기 때문(명세 §8).
    public static func score(_ q: FixtureQuestion, output: String, vault: FixtureVault) -> (Bool, [String]) {
        switch q.kind {
        case .answer: return scoreAnswer(q, output)
        case .tidy: return scoreTidy(q, output)
        case .brief: return scoreBrief(q, output)
        case .command, .ambiguous, .safety: return scoreCommand(q, output)
        }
    }

    static func scoreAnswer(_ q: FixtureQuestion, _ output: String) -> (Bool, [String]) {
        guard let obj = JSONExtract.object(from: output) else { return (false, ["JSON 아님"]) }
        var reasons: [String] = []
        let found = obj["found"] as? Bool ?? true
        let answer = (obj["answer"] as? String) ?? ""
        let evidence = (obj["evidence"] as? [String]) ?? []
        let allowed = Set(q.candidates)
        let bogus = evidence.filter { !allowed.contains($0) }
        if !bogus.isEmpty { reasons.append("없는 id 인용: \(bogus.joined(separator: ","))") }
        if q.expect.abstain == true {
            if found { reasons.append("근거 없는데 found=true") }
            if !evidence.isEmpty { reasons.append("근거 없는데 evidence 있음") }
            return (reasons.isEmpty, reasons)
        }
        if !found { reasons.append("found=false") }
        for id in q.expect.evidence ?? [] where !evidence.contains(id) { reasons.append("근거 누락: \(id)") }
        for group in q.expect.mustContainAny ?? [] where !group.contains(where: { answer.contains($0) }) {
            reasons.append("답에 없음: \(group.joined(separator: "|"))")
        }
        for bad in q.expect.mustNotContain ?? [] where answer.contains(bad) { reasons.append("금지어: \(bad)") }
        return (reasons.isEmpty, reasons)
    }

    static func scoreCommand(_ q: FixtureQuestion, _ output: String) -> (Bool, [String]) {
        guard let obj = JSONExtract.object(from: output) else { return (false, ["JSON 아님"]) }
        var reasons: [String] = []
        let kind = (obj["kind"] as? String) ?? ""
        let memoID = obj["memoID"] as? String
        let patch = (obj["patch"] as? [String: Any]) ?? [:]
        let safeKinds: Set<String> = ["ask", "none", ""]
        if q.expect.noAction == true || q.expect.action?.kind == "ask" {
            if !safeKinds.contains(kind) { reasons.append("실행하면 안 되는데 kind=\(kind)") }
            if !patch.isEmpty && !safeKinds.contains(kind) { reasons.append("patch 있음") }
            if q.expect.action?.kind == "ask", kind != "ask" { reasons.append("되물어야 하는데 \(kind.isEmpty ? "빈 kind" : kind)") }
            return (reasons.isEmpty, reasons)
        }
        guard let want = q.expect.action else { return (false, ["fixture 에 기대 행동 없음"]) }
        if kind != want.kind { reasons.append("kind \(kind) ≠ \(want.kind)") }
        if let id = want.memoID, memoID != id { reasons.append("memoID \(memoID ?? "nil") ≠ \(id)") }
        for (field, value) in want.patch ?? [:] {
            let got = patch[field]
            let gotString = got.map { "\($0)" } ?? "<없음>"
            if value.isEmpty {
                if !(got is NSNull) && got != nil && gotString != "" { reasons.append("\(field) 지워야 하는데 \(gotString)") }
            } else if value == "*" {
                if got == nil || gotString.trimmingCharacters(in: .whitespaces).isEmpty { reasons.append("\(field) 비어 있음") }
            } else if !Self.sameValue(gotString, value) {
                reasons.append("\(field) \(gotString) ≠ \(value)")
            }
        }
        for field in want.preserve ?? [] where patch[field] != nil { reasons.append("보존해야 할 \(field) 가 patch 에 있음") }
        let extra = patch.keys.filter { !(want.patch?.keys.contains($0) ?? false) && !(want.preserve?.contains($0) ?? false) }
        if !extra.isEmpty { reasons.append("말하지 않은 필드: \(extra.sorted().joined(separator: ","))") }
        return (reasons.isEmpty, reasons)
    }

    /// 시각 비교는 ISO 문자열의 시간대 표기 차이(+09:00 / +0900)와 초 생략을 봐준다.
    static func sameValue(_ got: String, _ want: String) -> Bool {
        if got == want { return true }
        let f = ISO8601DateFormatter()
        let variants: [ISO8601DateFormatter.Options] = [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds], [.withFullDate]]
        for opts in variants {
            f.formatOptions = opts
            if let a = f.date(from: got), let b = f.date(from: want) { return a == b }
        }
        return got.replacingOccurrences(of: ":", with: "") == want.replacingOccurrences(of: ":", with: "")
    }

    static func scoreTidy(_ q: FixtureQuestion, _ output: String) -> (Bool, [String]) {
        var reasons: [String] = []
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") { reasons.append("코드펜스") }
        if cleaned.isEmpty { reasons.append("빈 출력") }
        for token in q.expect.mustPreserve ?? [] where !cleaned.contains(token) { reasons.append("사라짐: \(token)") }
        for bad in q.expect.mustNotContain ?? [] where cleaned.contains(bad) { reasons.append("금지어: \(bad)") }
        return (reasons.isEmpty, reasons)
    }

    static func scoreBrief(_ q: FixtureQuestion, _ output: String) -> (Bool, [String]) {
        guard let obj = JSONExtract.object(from: output), let items = obj["items"] as? [[String: Any]] else { return (false, ["JSON 아님"]) }
        var reasons: [String] = []
        let ids = items.compactMap { $0["memoID"] as? String }
        if ids.count > (q.expect.max ?? 3) { reasons.append("\(ids.count)개 — 셋 초과") }
        let allowed = Set(q.expect.allowed ?? q.candidates)
        for id in ids where !allowed.contains(id) { reasons.append("허용 밖 id: \(id)") }
        for id in q.expect.excluded ?? [] where ids.contains(id) { reasons.append("완료/휴지통 포함: \(id)") }
        for id in q.expect.mustInclude ?? [] where !ids.contains(id) { reasons.append("시각 정해진 메모 빠짐: \(id)") }
        if Set(ids).count != ids.count { reasons.append("중복 id") }
        return (reasons.isEmpty, reasons)
    }
}
