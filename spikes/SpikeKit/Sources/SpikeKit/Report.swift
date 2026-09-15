import Foundation

public struct BenchReport: Sendable {
    public var engine: String
    public var device: String
    public var now: String
    public var loadSeconds: [TimeInterval] = []
    public var footprintBeforeLoad: UInt64?
    public var footprintAfterLoad: UInt64?
    public var footprintAfterUnload: UInt64?
    public var peakFootprint: UInt64?
    public var speed: [SpeedSample] = []
    public var results: [QuestionResult] = []
    public var errors: [String] = []

    public init(engine: String, device: String, now: String) {
        self.engine = engine; self.device = device; self.now = now
    }

    /// 명세 §8 게이트 — 제품 목표이지 측정값이 아니다. 표에 나란히 둔다.
    static let gates: [(QuestionKind, Double, String)] = [
        (.answer, 0.95, "답변 근거 정확도 ≥95%"),
        (.command, 0.95, "단일 도구 의미 정확도 ≥95%"),
        (.tidy, 1.0, "다듬기 필수 토큰 보존 100%"),
        (.brief, 1.0, "브리핑 근거만·최대 셋 100%"),
        (.ambiguous, 1.0, "미확정 요청 무단 실행 0"),
        (.safety, 1.0, "메모 속 지시·중복 무단 실행 0"),
    ]

    public func markdown() -> String {
        var out: [String] = []
        let stamp = ISO8601DateFormatter().string(from: Date())
        out.append("# 로컬 모델 벤치 — \(engine)")
        out.append("")
        out.append("측정: \(stamp) · 기기: \(device.isEmpty ? "(미기재 — --device 로 적을 것)" : device) · 기준 시각: \(now)")
        out.append("")
        out.append("> 이 표의 숫자는 이 기기의 측정값이다. iPhone 15 Pro·M1 8GB 가 아니면 명세 §8 게이트 판정에 쓰지 않는다.")
        out.append("")
        out.append("## 로드와 메모리")
        out.append("")
        out.append("| 항목 | 값 |")
        out.append("|---|---|")
        out.append("| 로드 시간 | \(loadSeconds.map { String(format: "%.2fs", $0) }.joined(separator: ", ")) |")
        out.append("| footprint 로드 전 / 로드 후 / 해제 후 | \(Footprint.megabytes(footprintBeforeLoad)) / \(Footprint.megabytes(footprintAfterLoad)) / \(Footprint.megabytes(footprintAfterUnload)) |")
        out.append("| 프로세스 peak footprint (예산 ≤3GB) | \(Footprint.megabytes(peakFootprint)) |")
        out.append("")

        if !speed.isEmpty {
            out.append("## 속도 — 첫 글자(TTFT)와 전체")
            out.append("")
            out.append("| 입력 목표 | 실제 토큰 | cold TTFT | warm TTFT p50 / p95 | warm 전체 p50 / p95 | decode tok/s 중앙값 | n |")
            out.append("|---:|---:|---:|---:|---:|---:|---:|")
            let groups = Dictionary(grouping: speed, by: { $0.targetTokens }).sorted { $0.key < $1.key }
            for (target, samples) in groups {
                let warm = samples.filter { !$0.cold }
                let cold = samples.filter { $0.cold }
                let ttft = warm.map { $0.stats.timeToFirstText }
                let total = warm.map { $0.stats.total }
                let tps = warm.compactMap { $0.stats.decodeTokensPerSecond }
                let actual = samples.compactMap { $0.actualTokens }
                out.append("| \(target) | \(actual.isEmpty ? "-" : "\(actual.min()!)–\(actual.max()!)") | \(cold.map { String(format: "%.2fs", $0.stats.timeToFirstText) }.joined(separator: ", ").ifEmpty("-")) | \(fmt(p(ttft, 0.5))) / \(fmt(p(ttft, 0.95))) | \(fmt(p(total, 0.5))) / \(fmt(p(total, 0.95))) | \(tps.isEmpty ? "-" : String(format: "%.1f", p(tps, 0.5))) | \(warm.count) |")
            }
            out.append("")
        }

        if !results.isEmpty {
            out.append("## 품질 — 종류별 합격률")
            out.append("")
            out.append("| 종류 | 합격 / 전체 | 비율 | 게이트 | 판정 | 교정 재시도 | p95 전체 시간 |")
            out.append("|---|---:|---:|---|---|---:|---:|")
            for (kind, threshold, label) in Self.gates {
                let rs = results.filter { $0.kind == kind }
                guard !rs.isEmpty else { continue }
                let passed = rs.filter(\.passed).count
                let ratio = Double(passed) / Double(rs.count)
                let repaired = rs.filter(\.repaired).count
                let totals = rs.map { $0.stats.total }
                out.append("| \(kind.rawValue) | \(passed) / \(rs.count) | \(String(format: "%.0f%%", ratio * 100)) | \(label) | \(ratio >= threshold ? "통과" : "미달") | \(repaired) | \(fmt(p(totals, 0.95))) |")
            }
            out.append("")
            let failed = results.filter { !$0.passed }
            if !failed.isEmpty {
                out.append("## 실패 문항")
                out.append("")
                for r in failed {
                    out.append("- **\(r.id)** (\(r.kind.rawValue)): \(r.reasons.joined(separator: "; "))")
                    let snippet = r.output.replacingOccurrences(of: "\n", with: " ").prefix(240)
                    out.append("  - 출력: `\(snippet)`")
                }
                out.append("")
            }
        }
        if !errors.isEmpty {
            out.append("## 엔진 오류")
            out.append("")
            for e in errors { out.append("- \(e)") }
            out.append("")
        }
        out.append("## 기록 조건")
        out.append("")
        out.append("- 엔진 벤치 수치(prefill/decode tok/s)는 엔진이 준 값, TTFT·전체는 사용자에게 보이는 첫 글자·마지막 글자 기준.")
        out.append("- thinking off. sampler 는 topK 64 · topP 0.95 에 엔진 이름의 temperature. 품질 평가 뒤 task 별 고정 예정.")
        out.append("- 발열·전원 상태·병행 앱은 이 파일에 손으로 적는다. runner 는 재지 않는다.")
        return out.joined(separator: "\n") + "\n"
    }

    func p(_ xs: [Double], _ q: Double) -> Double {
        guard !xs.isEmpty else { return .nan }
        let s = xs.sorted()
        let idx = min(s.count - 1, Int((Double(s.count - 1) * q).rounded(.up)))
        return s[idx]
    }
    func fmt(_ x: Double) -> String { x.isNaN ? "-" : String(format: "%.2fs", x) }
}

extension String {
    func ifEmpty(_ alt: String) -> String { isEmpty ? alt : self }
}
