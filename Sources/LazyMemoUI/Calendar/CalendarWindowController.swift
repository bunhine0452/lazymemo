import AppKit
import LazyMemoCore
import Observation
import SwiftUI

/// 「달력」 창.
///
/// 메모 창과 같은 규칙을 쓴다 (`DesktopLevelWindow`). 좌표는 `layout.json` 에
/// `calendar` 키로 남는다 — 메모가 아니므로 ULID 키를 쓰지 않는다.
@MainActor
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private static let layoutKey = "calendar"
    /// 일곱 칸이 손가락으로 겨냥할 만한 크기가 되는 최소 폭에서 시작한다.
    /// 여기서 더 좁히면 끌어다 놓기가 조준 게임이 된다.
    private static let defaultSize = NSSize(width: 300, height: 440)
    private static let minimumSize = NSSize(width: 272, height: 340)

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
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
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

    private func record(_ frame: CGRect) {
        layouts.set(WindowLayout(frame: frame), forKey: Self.layoutKey)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        if let frame = window?.frame { record(frame) }
    }

    func windowDidResize(_ notification: Notification) {
        if let frame = window?.frame { record(frame) }
    }
}
