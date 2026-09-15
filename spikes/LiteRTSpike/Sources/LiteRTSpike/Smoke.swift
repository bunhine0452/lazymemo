import Foundation
import SpikeKit

/// 로딩·스트리밍·취소·해제 한 바퀴. 숫자만 찍고 판단은 사람이 한다.
enum Smoke {
    static func run(generator: LiteRTGenerator, args: Args) async throws {
        print("엔진: \(generator.label)")
        print("로드 전 footprint: \(Footprint.megabytes(Footprint.current()))")

        let loadSeconds = try await generator.load()
        print(String(format: "로드: %.2fs · footprint %@", loadSeconds, Footprint.megabytes(Footprint.current())))

        let system = "너는 사용자의 메모만 근거로 짧게 답하는 한국어 비서다."
        let user = """
        근거 메모:
        [id: 01K5A0000000000000000000A1]
        due: 2026-09-20
        엄마 생신 선물 — 무릎 담요나 안마기 중에 고민. 예산 10만 원.

        사용자: 지난번 엄마 선물 뭐 사려고 했지?
        """

        // 1) 끝까지 스트리밍
        print("--- 생성 1 (끝까지)")
        var stats = try await generator.generate(system: system, user: user, maxOutputTokens: 128, jsonSchema: nil) { piece in
            FileHandle.standardOutput.write(piece.data(using: .utf8)!)
        }
        print("\n" + describe(stats))

        // 2) 취소 — 첫 글자 뒤 300ms 에 끊는다. 명세 §8: 1초 안에 새 출력이 멈춰야 한다.
        print("--- 생성 2 (취소)")
        generator.resetCancel()
        let cancelAt = CancelClock()
        let cancelTask = Task {
            await cancelAt.waitForFirstDelta()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await cancelAt.markCancelRequested()
            await generator.cancel()
        }
        stats = try await generator.generate(system: "너는 시키는 대로 길게 쓰는 도우미다.", user: "1부터 400까지 숫자를 한 줄에 하나씩 전부 써 줘.", maxOutputTokens: 512, jsonSchema: nil) { piece in
            Task { await cancelAt.delta(piece) }
        }
        _ = await cancelTask.result
        let summary = await cancelAt.summary(streamEnded: Date())
        print("출력 앞부분: " + stats.outputText.prefix(60).replacingOccurrences(of: "\n", with: " "))
        print(describe(stats))
        print(summary)
        generator.resetCancel()

        // 3) 해제 → 재로드
        print("--- 해제")
        await generator.unload()
        try? await Task.sleep(nanoseconds: 500_000_000)
        print("해제 뒤 footprint: \(Footprint.megabytes(Footprint.current())) · 수명 peak \(Footprint.megabytes(Footprint.lifetimePeak()))")
        let reload = try await generator.load()
        print(String(format: "재로드: %.2fs · footprint %@", reload, Footprint.megabytes(Footprint.current())))
        await generator.unload()
    }

    static func describe(_ s: GenerationStats) -> String {
        var parts = [String(format: "첫 글자 %.2fs · 전체 %.2fs · 출력 %d자", s.timeToFirstText, s.total, s.outputText.count)]
        if let p = s.prefillTokens, let d = s.decodeTokens { parts.append("prefill \(p) · decode \(d) tokens") }
        if let tps = s.decodeTokensPerSecond { parts.append(String(format: "%.1f tok/s", tps)) }
        if s.cancelled { parts.append("취소됨") }
        return parts.joined(separator: " · ")
    }
}

/// 취소 시점 앞뒤의 delta 를 센다 — 「취소 뒤에도 글자가 오는가」를 재는 자.
actor CancelClock {
    private var first: Date?
    private var cancelRequested: Date?
    private var deltasAfterCancel = 0
    private var lastDelta: Date?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func delta(_ piece: String) {
        let now = Date()
        lastDelta = now
        if first == nil {
            first = now
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
        if cancelRequested != nil { deltasAfterCancel += 1 }
    }

    func waitForFirstDelta() async {
        if first != nil { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func markCancelRequested() { cancelRequested = Date() }

    func summary(streamEnded: Date) -> String {
        guard let cancelRequested else { return "취소 요청이 없었다 (생성이 먼저 끝남)" }
        let stop = lastDelta.map { max(0, $0.timeIntervalSince(cancelRequested)) } ?? 0
        return String(format: "취소 → 마지막 delta %.2fs · 취소 뒤 delta %d개 · 취소 → 스트림 종료 %.2fs", stop, deltasAfterCancel, streamEnded.timeIntervalSince(cancelRequested))
    }
}
