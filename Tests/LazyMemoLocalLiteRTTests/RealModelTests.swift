import Foundation
import Testing
import LazyMemoCore
import LazyMemoAssistant
@testable import LazyMemoLocalLiteRT

/// 실모델 스위트 — `LAZYMEMO_MODEL_PATH=<gemma-4-E2B-it.litertlm>` 가 있을 때만 돈다 (명세 §8: opt-in 분리).
/// 2.4GB 파일을 복사하지 않고 symlink 로 store 자리에 앉힌다.
@Suite("LiteRTProvider · 실모델", .enabled(if: ProcessInfo.processInfo.environment["LAZYMEMO_MODEL_PATH"] != nil))
struct RealModelTests {
    struct MemorySource: EvidenceSource {
        let memos: [Memo]
        func search(_ query: String, limit: Int) async throws -> [Memo] { memos }
        func get(_ id: ULID) async throws -> Memo { memos.first { $0.id == id }! }
        func today(now: Date) async throws -> [Memo] { memos }
    }

    func makeStore() throws -> (ModelStore, URL) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-real-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = ModelStore(support: root)
        let m = ModelManifest.gemma4E2B
        try FileManager.default.createDirectory(at: store.directory(for: m), withIntermediateDirectories: true)
        let source = ProcessInfo.processInfo.environment["LAZYMEMO_MODEL_PATH"]!
        try FileManager.default.createSymbolicLink(atPath: store.activeURL(for: m).path(percentEncoded: false), withDestinationPath: source)
        return (store, root)
    }

    @Test("질문 → 근거 인용 답, 그리고 취소")
    func answerAndCancel() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let provider = LiteRTProvider(store: store, manifest: .gemma4E2B)
        #expect(await provider.availability == .ready)
        let dentist = Memo(due: CalendarDate(year: 2026, month: 9, day: 18),
                           at: ISO8601DateFormatter().date(from: "2026-09-18T05:00:00Z"),
                           body: "치과 예약 — 강남역 3번 출구 서울밝은치과. 스케일링.")
        let noise = Memo(body: "차 정기점검 — 성산동 한빛모터스.")
        let coordinator = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: [dentist, noise]), profile: ModelProfile(profileID: "test"))

        let start = Date()
        var events: [AssistantEvent] = []
        for await e in await coordinator.run(AssistantRequest(task: .answer, userText: "치과 예약 언제였지?")) { events.append(e) }
        let elapsed = Date().timeIntervalSince(start)
        print("실모델 답변까지 \(String(format: "%.2f", elapsed))s: \(events.last.map { "\($0)" } ?? "-")")
        // 배관을 단정한다 — 근거가 있으면 보여 준 id 만 인용했는지, 없다고 했으면 명시 상태인지. 품질은 벤치의 몫.
        switch events.last {
        case .completed(.answer(let answer)):
            #expect(answer.evidence.allSatisfy { [dentist.id, noise.id].contains($0) })
            #expect(!answer.text.isEmpty)
        case .failed(.noEvidence):
            break
        default:
            Issue.record("\(events)")
        }
        #expect(events.contains { if case .evidence = $0 { return true } else { return false } })

        // 취소 — tidy 는 글자를 흘리므로 첫 delta 에서 끊는다.
        let long = Memo(body: String(repeating: "회의 메모 정리 필요. 안건 여러 개. ", count: 40))
        let c2 = AssistantCoordinator(provider: provider, evidence: MemorySource(memos: [long]), profile: ModelProfile(profileID: "test"))
        let request = AssistantRequest(task: .tidy, userText: "", selectedMemoID: long.id)
        var deltas = 0
        var completed = false
        let cancelAt = Date()
        for await e in await c2.run(request) {
            if case .textDelta = e { deltas += 1; if deltas == 1 { await c2.cancel(request.id) } }
            if case .completed = e { completed = true }
        }
        print("취소 뒤 스트림 종료까지 \(String(format: "%.2f", Date().timeIntervalSince(cancelAt)))s · delta \(deltas)")
        #expect(!completed)
        #expect(deltas <= 3)
        await provider.unload()
    }
}
