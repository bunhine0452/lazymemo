import Foundation
import LazyMemoCore
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 저장소가 바뀌면 위젯을 다시 그리게 한다 — 앱이 위젯에게 말을 거는 유일한 문.
///
/// `SpotlightCenter` 와 같은 모양이다: `store.memos` 를 지켜보다 바뀌면 WidgetKit 에
/// 「그 종류를 다시 그려라」 한다. **연속된 변경은 한 번으로 모은다** — 저장 버튼이 없는
/// 앱이라 타자마다 파일이 바뀌는데, 그때마다 위젯을 다시 그리면 하루 예산을 아침에 다
/// 쓴다. 뒤로 물러날 때는 미룬 것을 바로 보낸다 (`flush`) — 곧 멈출 수 있어서.
///
/// WidgetKit 이 없는 빌드(`swift build` 의 시험 헬퍼)에서도 컴파일된다 — 그때는 아무 일도
/// 하지 않는다. 위젯이 없는 GitHub 판에서 부르는 것도 해가 없다: 그릴 위젯이 없을 뿐이다.
@MainActor
public final class WidgetRefresher {
    public static let shared = WidgetRefresher()

    /// 모으는 시간. 이 안에 또 바뀌면 처음부터 다시 센다.
    public static let coalescing: Duration = .seconds(2)

    private var store: MemoStore?
    private var pending: Task<Void, Never>?

    public init() {}

    /// 저장소를 붙이고 한 번 그리게 한다. 두 번 불러도 붙인 저장소는 그대로다.
    public func start(store: MemoStore) {
        guard self.store == nil else { reload(); return }
        self.store = store
        observe()
        reload()
    }

    private func observe() {
        guard let store else { return }
        withObservationTracking { _ = store.memos } onChange: {
            Task { @MainActor [weak self] in
                self?.observe()
                self?.reload()
            }
        }
    }

    /// 곧 다시 그리게 한다 — `coalescing` 안의 변경은 하나로.
    public func reload() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.coalescing)
            guard !Task.isCancelled else { return }
            self?.pending = nil
            Self.reloadNow()
        }
    }

    /// 미뤄 둔 것을 지금 보낸다. 앱이 뒤로 물러날 때 — 2초 뒤에는 멈춰 있을 수 있다.
    public func flush() {
        guard pending != nil else { return }
        pending?.cancel()
        pending = nil
        Self.reloadNow()
    }

    /// 세 위젯 전부를 다시 그리게 한다.
    public static func reloadNow() {
        #if canImport(WidgetKit)
        for identifier in WidgetKind.identifiers {
            WidgetCenter.shared.reloadTimelines(ofKind: identifier)
        }
        #endif
    }
}
