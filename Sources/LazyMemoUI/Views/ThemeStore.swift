import AppKit
import LazyMemoCore
import LazyMemoWidgetsCore
import Observation
import SwiftUI

/// 고른 테마 하나 — **창 전체가 함께 쓰는 값** (`PaperAppearance` 와 같은 자리).
///
/// 값 자체는 `ThemeRuntime` 이 들고 있다. 그리는 닫힘(`NSColor(name:)`)은 아무
/// 스레드에서나 불리므로 메인에 매인 것을 들여다볼 수 없기 때문이다. 이 클래스가
/// 하는 일은 둘뿐이다.
///
/// 1. **바꾸고 적는다** — 설정 파일(정본)과 App Group 의 거울(위젯이 보는 것)에.
/// 2. **다시 그리게 한다** — SwiftUI 는 `generation` 을 읽은 본문을 다시 부르고
///    (`Theme.track`), AppKit 뷰는 스스로 다시 그리지 않으므로 손으로 깨운다.
@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private(set) var resolved: ResolvedTheme
    /// 색이 바뀐 횟수. **본문이 색을 읽으면 이 값을 읽은 것이 된다** — 색을
    /// 읽는 자리가 칠백 곳이라 그 전부를 관찰 대상으로 바꾸는 대신, 색을 돌려주는
    /// 계산 속성이 이 한 칸을 스치고 간다 (`Theme.track`).
    private(set) var generation = 0

    /// 정본. 앱이 설정 파일을 연 뒤에 붙는다 — 그 전에는 거울만 보고 뜬다.
    private var settings: SettingsStore?

    init(resolved: ResolvedTheme = ThemeRuntime.shared.resolved) {
        self.resolved = resolved
    }

    var spec: ThemeSpec { resolved.spec }
    var id: ThemeID { resolved.id }
    var overrides: ThemeOverrides { resolved.overrides }

    /// 앱이 설정 파일을 열면 부른다 (`AppDelegate.open`). 파일이 정본이므로
    /// 거울과 다르면 **파일이 이긴다** — 사람이 손으로 고쳐 둔 것이 거기 있다.
    func attach(settings store: SettingsStore) {
        settings = store
        guard ProcessInfo.processInfo.environment["LAZYMEMO_THEME"] == nil else { return }
        let current = store.current
        guard let named = current.theme else {
            // **파일에 아직 아무것도 없다.** 거울이 들고 있던 것을 파일로 옮겨 적는다 —
            // 파일을 만나기 전에 고른 것(설정 창이 저장소보다 먼저 뜬 주행)이나
            // 앞선 판에서 고른 것이 여기서 사라지면 안 된다.
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

    /// 얹은 것 한 가지를 고친다 — 강조색·종이 색·글자 크기.
    func customize(_ change: (inout ThemeOverrides) -> Void) {
        var next = resolved.overrides
        change(&next)
        guard next != resolved.overrides else { return }
        apply(ResolvedTheme(id: resolved.id, overrides: next))
    }

    /// 「기본으로」 — 얹은 것만 털고 고른 테마는 남긴다. 테마까지 되돌리고
    /// 싶으면 견본에서 「크림과 포레스트」를 누르면 된다.
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
        ThemeChoice.save(id: next.id, overrides: next.overrides)
        // 홈 화면·알림 센터의 위젯도 같은 색을 입는다 — 거울을 적은 뒤 다시 그리게 한다.
        WidgetRefresher.shared.reload()
        redrawAppKit()
    }

    /// **AppKit 은 스스로 깨지 않는다.** 글이 앉는 자리는 `NSTextView` 이고
    /// (`MemoNSTextView`), 그 글자 색은 그릴 때 해석되는 동적 색이라 값은 이미
    /// 새것인데 화면만 옛 그림으로 남는다 — 외관을 바꿀 때는 시스템이 대신
    /// 깨워 주던 일이다.
    private func redrawAppKit() {
        for window in NSApp.windows {
            window.contentView?.needsDisplay = true
            window.contentView?.subviewsNeedDisplay()
        }
        NotificationCenter.default.post(name: ThemeStore.didChange, object: nil)
    }

    /// 색이 바뀌었다. 글자 색을 스스로 물고 있는 곳(마크다운 칠하기)이 다시
    /// 칠할 기회 — 지금은 동적 색이라 다시 그리기만 하면 되지만, 캐시를 들이면
    /// 여기 붙는다.
    static let didChange = Notification.Name("lazymemo.theme.did-change")
}

private extension NSView {
    func subviewsNeedDisplay() {
        needsDisplay = true
        for view in subviews { view.subviewsNeedDisplay() }
    }
}
