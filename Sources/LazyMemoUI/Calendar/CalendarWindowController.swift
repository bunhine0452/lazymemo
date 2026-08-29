import AppKit
import LazyMemoCore
import Observation
import SwiftUI

/// 「달력」 창.
///
/// 메모 창과 같은 규칙을 쓴다 (`DesktopLevelWindow`). 좌표는 `layout.json` 에
/// `calendar` 키로 남는다 — 메모가 아니므로 ULID 키를 쓰지 않는다.
///
/// **열려 있었는지도 함께 남긴다.** 날짜가 붙은 메모는 종이로 나오지 않으므로
/// (§7.2) 이 창이 곧 일정이 보이는 유일한 자리다. 껐다 켤 때마다 달력이
/// 사라지면 일정도 같이 사라진다.
@MainActor
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private static let layoutKey = "calendar"
    /// 일곱 칸이 손가락으로 겨냥할 만한 크기가 되는 최소 폭에서 시작한다.
    /// 여기서 더 좁히면 끌어다 놓기가 조준 게임이 된다.
    private static let defaultSize = NSSize(width: 300, height: 440)
    /// 세로로 선 창의 최소 높이는 340 이었다. 가로로 눕히면 그만큼이 필요
    /// 없다 — 접힌 자리가 세로로 서면서 아래에 쌓이던 목록이 옆으로 가므로,
    /// 짧고 넓은 창(예: 560×320)이 오히려 제 모양이다 (`CalendarLayout`).
    private static let minimumSize = NSSize(width: 272, height: 300)

    private let model: CalendarModel
    private let layouts: LayoutStore
    private let store: MemoStore
    private let onSelectMemo: (ULID) -> Void
    private var window: DesktopLevelWindow?

    init(store: MemoStore, layouts: LayoutStore, onSelectMemo: @escaping (ULID) -> Void) {
        self.store = store
        self.model = CalendarModel(store: store)
        self.layouts = layouts
        self.onSelectMemo = onSelectMemo
        super.init()
        observeStore()
        observeHolding()
    }

    /// 일정은 별도 타입이 아니라 메모의 필드다 (§10). 메모가 바뀌면 달력도 바뀐다.
    private func observeStore() {
        withObservationTracking {
            _ = store.memos
        } onChange: {
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observeStore()
            }
        }
    }

    /// 놓을 날을 기다리는 동안에는 창이 앞에 서 있어야 한다 (설계문서 §7.2).
    ///
    /// `riseBriefly` 를 길게 주는 것으로는 안 된다 — 겨누는 시간은 사람마다
    /// 다르고, 정해 둔 시간이 지나면 조준하던 판이 브라우저 뒤로 사라진다.
    /// 들고 있는 동안 서 있다가, 놓거나 그만두면 내려앉는다.
    private func observeHolding() {
        withObservationTracking {
            _ = model.holding
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if model.holding == nil { window?.settle() } else { window?.rise() }
                observeHolding()
            }
        }
    }

    var isOpen: Bool { window != nil }

    func toggle() { isOpen ? close() : open() }

    func open() {
        guard window == nil else { return }

        let frame = resolveFrame()
        let window = DesktopLevelWindow(contentRect: frame)
        window.minSize = Self.minimumSize

        let hosting = FirstMouseHostingView(rootView: CalendarView(
            model: model,
            onClose: { [weak self] in self?.close() },
            onSelectMemo: onSelectMemo
        ))
        // 창 크기는 layout.json 이 정본이다 (스파이크에서 배운 것).
        hosting.sizingOptions = []

        window.contentView = hosting
        window.setFrame(frame, display: false)
        window.delegate = self
        window.orderFront(nil)

        self.window = window
        record(frame)
    }

    func close() {
        // 들고 있던 것은 놓지 못한 것이다. 창을 치우면 손도 비운다 — 다음에
        // 열었을 때 "무엇을 놓으라는 거지" 가 남으면 안 된다.
        model.cancelHold()
        if let frame = window?.frame { record(frame, isOpen: false) }
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
    }

    /// 껐다 켜면 열려 있던 대로 돌아온다. 닫아 둔 사람에게는 아무 일도 없다.
    func restoreIfWasOpen() {
        guard layouts.layout(forKey: Self.layoutKey)?.hidden == false else { return }
        open()
    }

    /// 방금 적은 일정을 달력이 받는다 (설계문서 §7.2).
    ///
    /// 종이가 하던 몸짓 그대로다 — **포커스는 뺏지 않고** 잠깐 앞으로 나왔다
    /// 내려앉는다(`riseBriefly`). 적은 사람은 하던 일로 돌아가는 중이지 새 창을
    /// 받으러 온 것이 아니다.
    ///
    /// 닫혀 있었으면 연다. 일정을 적었는데 받을 달력이 없으면 그 일정은
    /// 화면 어디에도 나타나지 않고, 그 순간 "적히긴 한 건가" 가 남는다.
    func announce(_ day: CalendarDate) {
        model.select(day)
        open()
        refresh()
        window?.riseBriefly()
    }

    /// 종이에서 건너온 메모를 받아 든다 — 「달력에 놓기」의 착지점.
    ///
    /// 날짜를 묻는 상자를 띄우지 않는다. 이 창에는 날짜를 가리키는 방법이
    /// 이미 있고(칸을 누른다), 그것이 끌어다 놓기와 같은 낱말이다. 닫혀
    /// 있었으면 연다 — 받을 달력이 없으면 놓을 자리도 없다.
    func aim(at memo: Memo) {
        open()
        model.hold(memo)
        refresh()
        window?.rise()
    }

    /// 이 일정이 달력의 어디에 있는지 보여준다 — 종이의 날짜를 누른 경우.
    func reveal(_ day: CalendarDate) {
        announce(day)
    }

    func refresh() {
        guard isOpen else { return }
        Task { await model.refresh() }
    }

    private func resolveFrame() -> CGRect {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        guard let saved = layouts.layout(forKey: Self.layoutKey) else {
            // 기본 자리는 좌상단. 메모는 우상단부터 쌓이므로 서로 비켜간다.
            return CGRect(
                x: fallback.minX + 40,
                y: fallback.maxY - Self.defaultSize.height - 40,
                width: Self.defaultSize.width,
                height: Self.defaultSize.height
            )
        }
        return FrameClamping.restore(saved.frame, onto: screens, fallback: fallback)
    }

    private func record(_ frame: CGRect, isOpen: Bool = true) {
        layouts.set(WindowLayout(frame: frame, hidden: !isOpen), forKey: Self.layoutKey)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        if let frame = window?.frame { record(frame) }
    }

    func windowDidResize(_ notification: Notification) {
        if let frame = window?.frame { record(frame) }
    }
}
