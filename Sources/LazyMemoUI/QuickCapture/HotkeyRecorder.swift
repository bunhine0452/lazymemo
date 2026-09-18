import AppKit
import LazyMemoCore
import Observation
import SwiftUI

/// 단축키를 바꾸는 자리.
///
/// 목록에서 고르게 하지 않는다. **누르면 그게 단축키다** — 조합을 글로 설명해
/// 고르는 화면은 그 자체가 불편이고, 게다가 실제로 손이 닿는 조합인지는
/// 눌러 봐야 안다.
///
/// 되돌릴 길을 항상 열어 둔다: 다른 앱이 이미 쓰는 조합이면 등록에 실패하므로
/// 그 자리에서 말해 주고 원래 것을 그대로 둔다.
@MainActor
final class HotkeyRecorder {
    @MainActor
    @Observable
    final class Model {
        var current: Hotkey = .standard
        /// 무엇의 단축키를 바꾸는가 — 「빠른 입력」·「클립보드 즉시 메모」. 둘이 되고부터는 말해 줘야 안다.
        var title = ""
        /// 실패했을 때 보여줄 말. `nil` 이면 평소 안내를 보인다.
        var problem: String?
    }

    private let model = Model()
    private var panel: NSPanel?
    private var monitor: Any?
    /// 끝난 뒤에도 앱을 활성인 채 둘 것인가 — 설정 창에서 왔으면 그 창으로 돌아가야 한다.
    /// 메뉴바에서 왔으면 물러나 키보드를 하던 앱에 돌려준다.
    var keepsAppActive: () -> Bool = { false }

    /// - Parameters:
    ///   - title: 어느 동작의 단축키인지 — 패널 머리에 적힌다.
    ///   - apply: 고른 조합을 실제로 등록해 본다. 됐으면 `nil`, 안 됐으면 그 까닭 한 줄.
    func begin(current: Hotkey, title: String, apply: @escaping (Hotkey) -> String?) {
        model.current = current
        model.title = title
        model.problem = nil

        let panel = makePanel(apply: apply)
        self.panel = panel

        panel.center()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel != nil else { return event }
            self.capture(event, apply: apply)
            return nil   // 녹음 중에는 어떤 키도 앱으로 흘려보내지 않는다
        }
    }

    func close() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel?.orderOut(nil)
        panel = nil
        if NSApp.isActive, !keepsAppActive() { NSApp.deactivate() }
    }

    private func capture(_ event: NSEvent, apply: (Hotkey) -> String?) {
        // esc 하나만 누르면 그만둔다. 보조키가 붙어 있으면 그건 단축키다.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, flags.isEmpty {
            close()
            return
        }

        let candidate = Hotkey(
            keyCode: UInt32(event.keyCode),
            modifiers: Hotkey.carbonModifiers(from: event.modifierFlags)
        )

        guard candidate.isUsable else {
            model.problem = L("⌘ ⌥ ⌃ ⇧ 중 하나를 함께 눌러 주세요")
            return
        }
        if let problem = apply(candidate) {
            model.problem = problem
            return
        }
        model.current = candidate
        close()
    }

    private func makePanel(apply: @escaping (Hotkey) -> String?) -> NSPanel {
        let panel = RecorderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .none

        let hosting = FirstMouseHostingView(
            rootView: HotkeyRecorderView(model: model, onCancel: { [weak self] in self?.close() })
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        return panel
    }
}

/// borderless 패널은 기본적으로 키가 못 된다. 키를 받아야 하므로 연다.
private final class RecorderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct HotkeyRecorderView: View {
    @Bindable var model: HotkeyRecorder.Model
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.snug) {
            Text(model.title)
                .font(Theme.micro)
                .foregroundStyle(.secondary)
            Text(L("새 단축키를 누르세요"))
                .font(Theme.title)
                .foregroundStyle(Paper.ink)

            Text(model.current.displayName)
                .font(.system(size: 26, weight: .light, design: .rounded))
                .foregroundStyle(Theme.accentInk)
                .padding(.horizontal, Theme.normal)
                .padding(.vertical, Theme.tight)
                .background(
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .fill(Theme.accentInk.opacity(0.12))
                )

            Text(model.problem ?? L("esc 로 그만두기"))
                .font(Theme.micro)
                .foregroundStyle(model.problem == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.sunday))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.loose)
        .frame(width: 320)
        .background(Theme.paper(MemoColor.gray.ink, radius: Theme.panelRadius, dotted: false))
        .overlay(Theme.edge(radius: Theme.panelRadius))
        .animation(Theme.reveal, value: model.problem)
        .onExitCommand(perform: onCancel)
    }
}
