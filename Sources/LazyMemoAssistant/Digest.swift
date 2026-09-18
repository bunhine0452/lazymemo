import Foundation
import LazyMemoCore

/// 웹에서 찾은 것을 **읽기 좋은 메모 한 장**으로.
///
/// 사용자: 「웹 검색 후 정리하여 메모 내용이 어떤 데이터라도 "잘" 정리되어 사용자가 보기 편하게」(2026-09-18).
/// 어떤 데이터가 와도 자리가 같아야 편하다 — 그래서 틀을 앱이 들고, 모델에게는 **가운데만** 맡긴다:
///
///     # 제목                     ← 앱 (물음이 곧 제목이다)
///     답 한두 문장               ← 모델 (없으면 앱이 답 문장을 그대로)
///     ## 핵심                    ← 모델 (없으면 앱이 발췌로)
///     ## 세부                    ← 모델 (표·번호 목록·할 일. 그럴 것이 없으면 아예 없다)
///     ## 출처                    ← **앱만** (제목 — 주소)
///     「물음」 웹에서 찾음 · 9월 18일  ← 앱
///
/// 출처를 모델에게 맡기지 않는 이유는 `WebFollowUp.attachSources` 때와 같다 — 작은 모델은 주소를
/// 잘라 먹고, 지어낸 주소는 거짓 근거다. 앱이 붙이면 언제나 맞다.
public enum Digest {
    public static let coreHeading = "## 핵심"
    public static let detailHeading = "## 세부"
    public static let sourceHeading = "## 출처"
    /// 모델이 스스로 붙이려 드는 머리글들 — 앱이 붙일 것이므로 걷어낸다.
    static let sourceWords = ["## 출처", "### 출처", "출처:", "## 참고", "## 링크", "## sources", "## source", "## references"]

    // MARK: 모델에게 줄 초안

    /// 모델이 읽을 글 — 물음·답·근거 본문. **주소는 넣지 않는다**(앱이 뒤에 단다).
    ///
    /// 근거는 발췌 한 줄이 아니라 페이지 본문(`Evidence.passage`)이다 — 정리의 「핵심」이 발췌
    /// 되풀이가 아니라 **내용**이 되는 것은 여기서 갈린다.
    public static func draft(question: String, answer: AssistantAnswer, results: [Evidence]) -> String {
        var parts: [String] = ["물음: \(WebQuery.make(from: question))"]
        let text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !isGeneric(text) { parts.append("지금까지의 답: \(text)") }
        let picked = shown(answer: answer, results: results)
        let budget = PageBudget.perSource(max(1, picked.count))
        for (index, e) in picked.enumerated() {
            var block = "[\(index + 1)] \(e.title ?? e.url?.host() ?? "")"
            let body = e.passage?.isEmpty == false ? e.passage! : e.excerpt
            if !body.isEmpty { block += "\n" + Readable.clip(body, to: budget) }
            parts.append(block)
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: 메모 짓기

    /// 모델이 쓴 가운데를 앱의 틀에 끼운다. 모델의 글을 못 쓰겠으면 앱만으로 짓는다(`compose`).
    public static func assemble(question: String, answer: AssistantAnswer, written: String,
                                results: [Evidence], footer: String) -> String {
        guard let middle = repair(written) else {
            return compose(question: question, answer: answer, results: results, footer: footer)
        }
        let picked = shown(answer: answer, results: results)
        var lines = [title(question: question, answer: answer), "", middle]
        // 모델이 「핵심」을 빠뜨렸으면 앱이 세운다 — 자리가 비면 메모는 다시 검색 결과 더미가 된다.
        if !middle.contains(coreHeading) {
            lines.append(contentsOf: ["", coreHeading] + bullets(from: picked))
        }
        lines.append(contentsOf: sourceBlock(picked) + ["", footer])
        return tightened(lines)
    }

    /// 모델 없이 — 답 문장과 근거 발췌만으로 같은 자리를 채운다. 폰에 모델이 없어도 메모는 정돈돼 있다.
    public static func compose(question: String, answer: AssistantAnswer, results: [Evidence], footer: String) -> String {
        let picked = shown(answer: answer, results: results)
        let text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [title(question: question, answer: answer), ""]
        if !text.isEmpty, !isGeneric(text) { lines.append(contentsOf: [text, ""]) }
        lines.append(contentsOf: [coreHeading] + bullets(from: picked))
        lines.append(contentsOf: sourceBlock(picked) + ["", footer])
        return tightened(lines)
    }

    /// 「메모로 남기기」— 정리하지 않고 그대로. 그래도 자리는 같다: 제목·답·출처·꼬리.
    ///
    /// 앞선 판은 제목 없이 답 한 줄과 «제목/발췌/주소» 세 줄 뭉치를 출처마다 쌓았다. 읽는 사람에게는
    /// 그것이 검색 페이지의 복사본으로 보인다 — 메모 목록에 서는 제목도 없었다.
    public static func keep(question: String, answer: AssistantAnswer, results: [Evidence], footer: String) -> String {
        let picked = shown(answer: answer, results: results)
        let text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [title(question: question, answer: answer), ""]
        if !text.isEmpty, !isGeneric(text) { lines.append(contentsOf: [text, ""]) }
        lines.append(sourceHeading)
        for e in picked {
            guard let url = e.url else { continue }
            lines.append("- \(e.title ?? url.host() ?? url.absoluteString) — \(url.absoluteString)")
            let note = highlight(e)
            if !note.isEmpty { lines.append("  \(note)") }
        }
        lines.append(contentsOf: ["", footer])
        return tightened(lines)
    }

    // MARK: 조각

    /// 물음이 곧 제목이다 — 목록에 서는 한 줄이 「검색 결과」여서는 안 된다 (`Memo.title` 이 «# » 를 걷는다).
    public static func title(question: String, answer: AssistantAnswer) -> String {
        let asked = WebQuery.make(from: question).trimmingCharacters(in: .whitespacesAndNewlines)
        if !asked.isEmpty { return "# " + String(asked.prefix(60)) }
        let text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        // `LazyMemoAssistant` 에는 표가 없다 — 이 모듈의 사람 말은 `AssistantFailure.message` 와 같이 한국어 그대로다.
        guard !text.isEmpty, !isGeneric(text) else { return "# 웹에서 찾은 것" }
        return "# " + String(text.split(separator: "\n").first?.prefix(60) ?? "")
    }

    /// 답이 인용한 것 먼저, 인용이 없으면 보여 준 앞의 셋.
    public static func shown(answer: AssistantAnswer, results: [Evidence], limit: Int = 3) -> [Evidence] {
        let cited = answer.sources.map(\.id)
        let picked = results.filter { cited.contains($0.memoID) }
            .sorted { (cited.firstIndex(of: $0.memoID) ?? 0) < (cited.firstIndex(of: $1.memoID) ?? 0) }
        return picked.isEmpty ? Array(results.prefix(limit)) : Array(picked.prefix(limit))
    }

    /// 근거마다 한 줄 — 모델이 「핵심」을 못 냈을 때 그 자리를 채운다.
    static func bullets(from picked: [Evidence]) -> [String] {
        let lines = picked.compactMap { e -> String? in
            let note = highlight(e)
            return note.isEmpty ? nil : "- \(note)"
        }
        return lines.isEmpty ? ["- 검색 결과의 링크를 아래에 두었습니다"] : lines
    }

    /// 근거 하나에서 건질 한 줄 — 발췌가 먼저다(검색 엔진이 물음에 맞춰 고른 문장이라 대개 이것이 맞다).
    static func highlight(_ e: Evidence, limit: Int = 140) -> String {
        for candidate in [e.excerpt, e.passage ?? ""] {
            let line = candidate.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                .first { $0.count >= 10 }
            if let line { return Readable.clip(line, to: limit) }
        }
        return ""
    }

    static func sourceBlock(_ picked: [Evidence]) -> [String] {
        let rows = picked.compactMap { e -> String? in
            guard let url = e.url else { return nil }
            return "- \(e.title ?? url.host() ?? url.absoluteString) — \(url.absoluteString)"
        }
        return rows.isEmpty ? [] : ["", sourceHeading] + rows
    }

    /// 앱이 대신 세운 머리글(「검색 결과에서 이 부분을 찾았어요」)은 답 문장이 아니다.
    static func isGeneric(_ text: String) -> Bool {
        text.hasPrefix("검색 결과에서") || text.hasPrefix("메모에서")
    }

    static func tightened(_ lines: [String]) -> String {
        var out: [String] = []
        for line in lines {
            // 빈 줄이 겹치면 한 줄로 — 조각을 이어 붙이다 보면 반드시 생긴다.
            if line.isEmpty, out.last?.isEmpty ?? true { continue }
            out.append(line)
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: 모델 글 다듬기·검사

    /// 모델이 낸 글에서 **쓸 수 있는 가운데**만. 못 쓰겠으면 nil.
    ///
    /// 걷어내는 것 넷 — 코드펜스(`ClaudePrompts.clean`) · 제 손으로 단 제목 줄 · 「출처」 아래 전부 ·
    /// 본문에 흘린 주소. 주소를 지우는 이유는 앱이 «## 출처» 를 정확한 주소로 붙이기 때문이다:
    /// 둘이 함께 있으면 어느 쪽이 맞는지 사람이 알 길이 없다.
    public static func repair(_ written: String) -> String? {
        var lines = ClaudePrompts.clean(written).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // 제목은 앱의 것이다.
        while let first = lines.first, first.hasPrefix("#") || first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        if let cut = lines.firstIndex(where: { line in
            let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)
            return sourceWords.contains { lowered.hasPrefix($0) }
        }) {
            lines = Array(lines[..<cut])
        }
        lines = lines.map { line in
            // `[기상청](https://…)` 는 이름만 남긴다 — 주소만 지우면 대괄호가 덩그러니 남는다.
            line.replacingOccurrences(of: #"\[([^\]]*)\]\(\s*https?://[^)]*\)"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"\(?\s*https?://\S+?\)?(?=\s|$)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression)
        }
        // 주소만 있던 줄은 이제 빈 줄이다.
        let body = tightened(lines)
        guard body.count >= 20 else { return nil }
        return body
    }

    /// 메모의 자리가 갖춰졌는가 — 시험과 수리가 같은 잣대를 본다. 빈 배열이면 잘 정돈된 것이다.
    public static func problems(in body: String) -> [String] {
        var out: [String] = []
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first else { return ["빈 메모"] }
        if !first.hasPrefix("# ") || first.count <= 2 { out.append("첫 줄이 제목이 아니다") }
        guard let core = lines.firstIndex(of: coreHeading) else {
            out.append("「\(coreHeading)」이 없다")
            return out + sourceProblems(lines)
        }
        let after = lines[lines.index(after: core)...]
        let bullets = after.prefix { !$0.hasPrefix("## ") }.filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
        if bullets.isEmpty { out.append("「\(coreHeading)」 아래에 줄이 없다") }
        return out + sourceProblems(lines)
    }

    static func sourceProblems(_ lines: [String]) -> [String] {
        guard let head = lines.firstIndex(of: sourceHeading) else { return ["「\(sourceHeading)」가 없다"] }
        let rows = lines[lines.index(after: head)...].prefix { !$0.hasPrefix("## ") }
        return rows.contains { $0.contains("http") } ? [] : ["출처에 주소가 없다"]
    }
}
