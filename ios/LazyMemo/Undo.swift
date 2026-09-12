import Foundation
import Observation

/// 되돌리기 띠 — 펜 바로 위 8초 (MOBILE_DESIGN §4).
///
/// 낱말은 셋이다: 「지웠습니다」·「9월 16일로 옮겼습니다」·「날짜를 뗐습니다」.
/// 방금 무엇이 어디로 갔는지를 다시 찾게 하지 않는다. 8초가 지나면 띠는
/// 사라지지만 지운 메모는 휴지통에 30일 있다 (D6).
@Observable
final class UndoModel {
    struct Offer: Identifiable {
        let id = UUID()
        let message: String
        let undo: () async -> Void
    }

    private(set) var offer: Offer?
    private var expiry: Task<Void, Never>?

    static let lifetime: Duration = .seconds(8)

    func offer(_ message: String, undo: @escaping () async -> Void) {
        expiry?.cancel()
        let fresh = Offer(message: message, undo: undo)
        offer = fresh
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.lifetime)
            guard !Task.isCancelled, let self, self.offer?.id == fresh.id else { return }
            self.offer = nil
        }
    }

    func take() async {
        guard let offer else { return }
        self.offer = nil
        expiry?.cancel()
        await offer.undo()
    }

    func dismiss() {
        expiry?.cancel()
        offer = nil
    }
}
