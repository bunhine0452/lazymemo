import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 빠른 입력 상자의 안내 문구가 **열 때마다 바뀌는지.**
///
/// 고정된 안내는 며칠이면 벽지가 되어 읽히지 않는다. 그래서 매번 다른 것을
/// 내놓기로 했는데, 무작위로 뽑으면 같은 것이 연달아 나오는 날이 있고 그때는
/// "안 바뀐다" 로 보인다 — 사람 눈에는 그 한 번이 규칙의 전부다.
@MainActor
@Suite("빠른 입력 — 안내 문구는 열 때마다 바뀐다")
struct CapturePromptTests {
    @Test("같은 문구를 두 번 연속 내놓지 않는다")
    func neverRepeatsBackToBack() {
        var previous = CapturePrompt.next(after: nil)
        for _ in 0..<200 {
            let next = CapturePrompt.next(after: previous)
            #expect(next != previous)
            previous = next
        }
    }

    @Test("뽑은 것은 언제나 준비된 문구 중 하나다")
    func staysInsideThePool() {
        for _ in 0..<50 {
            #expect(CapturePrompt.all.contains(CapturePrompt.next(after: nil)))
        }
    }

    @Test("문구는 한 줄에 들어갈 만큼 짧다")
    func staysShortEnoughForOneLine() {
        for prompt in CapturePrompt.all {
            #expect(!prompt.isEmpty)
            // 19pt 로 440pt 상자에 한 줄. 넉넉히 잡아도 이 정도가 한계다.
            #expect(prompt.count <= 20)
        }
    }

    private func makeModel() throws -> QuickCaptureModel {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-prompt-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return QuickCaptureModel(store: try MemoStore(paths: paths))
    }

    @Test("상자를 열 때마다 모델이 새 문구를 집는다")
    func theModelPicksAFreshOneOnEachShow() throws {
        let model = try makeModel()
        var seen: Set<String> = [model.placeholder]

        for _ in 0..<20 {
            model.prepareForShow()
            seen.insert(model.placeholder)
        }

        // 스무 번을 열었는데 한 가지만 봤다면 바뀌지 않는 것이다.
        #expect(seen.count > 1)
    }
}
