import Foundation

public struct BenchOptions: Sendable {
    public var repeats: Int
    public var speedRepeats: Int
    public var kinds: Set<QuestionKind>?
    public var skipSpeed: Bool
    public var skipQuality: Bool
    public var deviceNote: String
    public var verbose: Bool
    /// JSON schema 제약 디코딩을 쓴다 (엔진이 지원할 때만).
    public var constrained: Bool

    public init(repeats: Int = 1, speedRepeats: Int = 3, kinds: Set<QuestionKind>? = nil,
                skipSpeed: Bool = false, skipQuality: Bool = false, deviceNote: String = "", verbose: Bool = false,
                constrained: Bool = false) {
        self.repeats = max(1, repeats)
        self.speedRepeats = max(1, speedRepeats)
        self.kinds = kinds
        self.skipSpeed = skipSpeed
        self.skipQuality = skipQuality
        self.deviceNote = deviceNote
        self.verbose = verbose
        self.constrained = constrained
    }
}

public struct SpeedSample: Sendable {
    public var promptID: String
    public var targetTokens: Int
    public var actualTokens: Int?
    public var cold: Bool
    public var stats: GenerationStats
}

/// 명세 §8 의 측정 방식 그대로: 순차 로드, 품질 suite N회, 속도는 고정 프롬프트 × 반복,
/// cold(로드 직후 첫 생성)/warm 따로, 실제 토큰 수 보관, 앱 전체 peak memory 기록.
public final class BenchRunner {
    let generator: TextGenerator
    let vault: FixtureVault
    let questions: FixtureQuestions
    let speed: FixtureSpeed
    let options: BenchOptions
    let sampler = PeakSampler()

    public init(generator: TextGenerator, fixturesDirectory: URL, options: BenchOptions) throws {
        self.generator = generator
        (vault, questions, speed) = try FixtureLoader.loadAll(directory: fixturesDirectory)
        self.options = options
    }

    public func run() async throws -> BenchReport {
        var report = BenchReport(engine: generator.label + (options.constrained && generator.supportsSchema ? " · schema" : ""), device: options.deviceNote, now: vault.now)
        report.footprintBeforeLoad = Footprint.current()

        for round in 0..<options.repeats {
            let loadSeconds = try await generator.load()
            report.loadSeconds.append(loadSeconds)
            report.footprintAfterLoad = Footprint.current()
            sampler.sample()

            if !options.skipSpeed {
                try await runSpeed(round: round, into: &report)
            }
            if !options.skipQuality {
                try await runQuality(round: round, into: &report)
            }
            await generator.unload()
            try? await Task.sleep(nanoseconds: 300_000_000)
            report.footprintAfterUnload = Footprint.current()
        }
        report.peakFootprint = Footprint.lifetimePeak() ?? sampler.value
        return report
    }

    private func runSpeed(round: Int, into report: inout BenchReport) async throws {
        for (i, prompt) in speed.items.enumerated() {
            let tokens = try await generator.tokenCount(system: prompt.system, user: prompt.user)
            for rep in 0..<options.speedRepeats {
                let cold = (i == 0 && rep == 0)
                let stats: GenerationStats
                do {
                    stats = try await generator.generate(
                        system: prompt.system, user: prompt.user, maxOutputTokens: prompt.maxOutputTokens, jsonSchema: nil) { _ in }
                } catch {
                    // 토큰 초과·엔진 오류는 명시 상태로 남기고 계속 간다 (명세 §9).
                    report.errors.append("speed \(prompt.id): \(error)")
                    if options.verbose { print("[speed r\(round)] \(prompt.id) ERROR \(error)") }
                    continue
                }
                sampler.sample()
                report.speed.append(SpeedSample(promptID: prompt.id, targetTokens: prompt.targetTokens, actualTokens: stats.prefillTokens ?? tokens, cold: cold, stats: stats))
                if options.verbose {
                    print(String(format: "[speed r%d] %@ %@ tokens=%@ ttft=%.2fs total=%.2fs", round, prompt.id, cold ? "cold" : "warm", (stats.prefillTokens ?? tokens).map(String.init) ?? "-", stats.timeToFirstText, stats.total))
                }
            }
        }
    }

    private func runQuality(round: Int, into report: inout BenchReport) async throws {
        let items = questions.items.filter { options.kinds?.contains($0.kind) ?? true }
        for q in items {
            let system = SpikePrompts.system(for: q.kind, now: vault.now)
            let user = SpikePrompts.user(for: q, vault: vault)
            let tokens = try? await generator.tokenCount(system: system, user: user)
            let maxOut = SpikePrompts.maxOutput(for: q.kind)
            let schema = options.constrained ? SpikePrompts.jsonSchema(for: q.kind) : nil
            var stats: GenerationStats
            do {
                stats = try await generator.generate(system: system, user: user, maxOutputTokens: maxOut, jsonSchema: schema) { _ in }
            } catch {
                report.errors.append("\(q.id): \(error)")
                report.results.append(QuestionResult(id: q.id, kind: q.kind, passed: false, reasons: ["엔진 오류: \(error)"], output: "", stats: GenerationStats(timeToFirstText: 0, total: 0, outputText: ""), inputTokens: nil, repaired: false))
                if options.verbose { print("[\(q.kind.rawValue) r\(round)] \(q.id) ERROR \(error)") }
                continue
            }
            sampler.sample()
            var (passed, reasons) = Scoring.score(q, output: stats.outputText, vault: vault)
            var repaired = false
            // 명세 §3: 잘못된 구조 출력은 한 번만 교정 요청. 다시 실패하면 그대로 실패.
            if !passed, q.kind != .tidy, reasons == ["JSON 아님"] {
                let retryUser = user + "\n\n앞선 답은 JSON 이 아니었다. " + SpikePrompts.jsonRule
                let second = try await generator.generate(system: system, user: retryUser, maxOutputTokens: maxOut, jsonSchema: schema) { _ in }
                stats.total += second.total
                stats.outputText = second.outputText
                (passed, reasons) = Scoring.score(q, output: second.outputText, vault: vault)
                repaired = true
            }
            report.results.append(QuestionResult(id: q.id, kind: q.kind, passed: passed, reasons: reasons, output: stats.outputText, stats: stats, inputTokens: stats.prefillTokens ?? tokens, repaired: repaired))
            if options.verbose {
                print("[\(q.kind.rawValue) r\(round)] \(q.id) \(passed ? "PASS" : "FAIL") \(reasons.joined(separator: "; "))")
            }
        }
    }
}
