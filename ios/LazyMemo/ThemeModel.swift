import LazyMemoCore
import LazyMemoWidgetsCore
import Observation
import SwiftUI

/// 폰이 고른 테마 하나 — 맥의 `ThemeStore` 와 같은 일을 한다.
///
/// 값은 `ThemeRuntime` 이 들고 있다. `UIColor { traits in … }` 는 그릴 때
/// 불리므로 메인에 매인 것을 들여다볼 수 없기 때문이다. 이 모델이 하는 일은
/// **적는 것과 다시 그리게 하는 것** 둘뿐이다.
@MainActor
@Observable
final class ThemeModel {
    static let shared = ThemeModel()

    private(set) var resolved: ResolvedTheme
    /// 색이 바뀐 횟수. 색을 읽은 본문이 이 값을 읽은 것이 되어 다시 그려진다
    /// (`Theme.track`).
    private(set) var generation = 0

    private var settings: SettingsStore?

    init(resolved: ResolvedTheme = ThemeRuntime.shared.resolved) {
        self.resolved = resolved
    }

    var spec: ThemeSpec { resolved.spec }
    var id: ThemeID { resolved.id }
    var overrides: ThemeOverrides { resolved.overrides }

    /// 저장소가 열리면 붙는다. **파일이 정본이다** — 맥에서 고른 것이 iCloud 로
    /// 건너와 있으면 그 쪽이 이긴다 (`settings.json` 은 같은 폴더에 있다).
    func attach(settings store: SettingsStore) {
        settings = store
        let current = store.current
        guard let named = current.theme else {
            // 파일에 아직 아무것도 없으면 거울이 들고 있던 것을 파일로 옮겨 적는다.
            if !(resolved.id == .creamForest && resolved.overrides.isEmpty) { apply(resolved) }
            return
        }
        let fromFile = ResolvedTheme(id: ThemeID.parsed(named), overrides: current.themeOverrides ?? .none)
        guard fromFile != resolved else { return }
        apply(fromFile)
    }

    func select(_ id: ThemeID) {
        guard id != resolved.id else { return }
        apply(ResolvedTheme(id: id, overrides: resolved.overrides))
    }

    func customize(_ change: (inout ThemeOverrides) -> Void) {
        var next = resolved.overrides
        change(&next)
        guard next != resolved.overrides else { return }
        apply(ResolvedTheme(id: resolved.id, overrides: next))
    }

    /// 「기본으로」 — 얹은 것만 털고 고른 테마는 남긴다.
    func resetCustom() {
        guard !resolved.overrides.isEmpty else { return }
        apply(ResolvedTheme(id: resolved.id))
    }

    private func apply(_ next: ResolvedTheme) {
        resolved = next
        ThemeRuntime.shared.set(next)
        generation &+= 1
        settings?.update {
            $0.theme = next.id == .creamForest && next.overrides.isEmpty ? nil : next.id.rawValue
            $0.themeOverrides = next.overrides.isEmpty ? nil : next.overrides
        }
        // 홈 화면의 위젯이 같은 자리를 본다 (`ThemeChoice`).
        ThemeChoice.save(id: next.id, overrides: next.overrides)
        // 홈 화면·알림 센터의 위젯도 같은 색을 입는다 — 거울을 적은 뒤 다시 그리게 한다.
        WidgetRefresher.shared.reload()
    }
}
