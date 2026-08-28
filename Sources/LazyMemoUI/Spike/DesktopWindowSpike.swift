import AppKit
import Observation
import SwiftUI

/// `{#window-spike}` — 바탕화면 창이 실제 macOS 환경에서 버티는지 확인하는 도구.
///
/// 설계문서 §7 이 프로젝트 최대 리스크로 지목한 영역이다. Stage Manager,
/// Mission Control, 월페이퍼 클릭, 다중 디스플레이는 코드로 흉내 낼 수 없어
/// **사람이 직접 조작해 봐야 한다.** 그래서 스파이크를 "떠 있는 창" 이 아니라
/// "무슨 일이 일어났는지 세어서 보여주는 창" 으로 만들었다.
@MainActor
final class DesktopWindowSpike {
    private var window: DesktopLevelWindow?
    private let probe = WindowProbe()

    var isOpen: Bool { window != nil }

    func toggle() {
        if isOpen { close() } else { open() }
    }

    func open() {
        guard window == nil else { return }

        let size = NSSize(width: 340, height: 380)
        let window = DesktopLevelWindow(contentRect: NSRect(origin: .zero, size: size))

        let hosting = NSHostingView(rootView: SpikeCard(probe: probe))
        // 기본값이면 SwiftUI 뷰의 이상적 크기가 창 크기를 끌고 간다 —
        // maxHeight: .infinity 를 쓴 카드가 창을 화면 끝까지 늘려버렸다.
        // 창 크기는 layout.json 이 정본이 될 값이므로 뷰에 넘기지 않는다.
        hosting.sizingOptions = []
        window.contentView = hosting

        // contentView 를 붙인 뒤에 놓는다. 붙이는 순간 크기가 재조정될 수 있어
        // init 의 contentRect 만으로는 최종 크기가 보장되지 않는다.
        window.setFrame(
            NSRect(origin: Self.defaultOrigin(for: size), size: size),
            display: false
        )
        window.orderFront(nil)
        self.window = window

        probe.start(observing: window)
    }

    func close() {
        probe.stop()
        window?.orderOut(nil)
        window = nil
    }

    /// 주 디스플레이 우상단에서 조금 안쪽. 메뉴바와 겹치지 않게 띄운다.
    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(
            x: frame.maxX - size.width - 40,
            y: frame.maxY - size.height - 40
        )
    }
}

// MARK: - 관측

/// 창 하나를 지켜보며 환경 변화를 센다.
@MainActor
@Observable
final class WindowProbe {
    private(set) var levelDescription = "—"
    private(set) var screenDescription = "—"
    private(set) var frameDescription = "—"
    private(set) var spaceChanges = 0
    private(set) var screenChanges = 0
    private(set) var lastEvent = "없음"

    private weak var window: NSWindow?
    private var observers: [any NSObjectProtocol] = []

    /// 바탕화면 아이콘 레벨과의 차이를 함께 보여준다 — 숫자 하나만으로는
    /// "제대로 배치됐는지" 판단할 수 없기 때문이다.
    func start(observing window: NSWindow) {
        self.window = window
        refresh()

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.spaceChanges += 1
                self.lastEvent = "Space 전환"
                self.refresh()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.screenChanges += 1
                self.lastEvent = "디스플레이 구성 변경"
                self.refresh()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lastEvent = "창 이동"
                self?.refresh()
            }
        })
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        window = nil
    }

    private func refresh() {
        guard let window else { return }

        let desktopIcon = Int(CGWindowLevelForKey(.desktopIconWindow))
        let normal = Int(CGWindowLevelForKey(.normalWindow))
        levelDescription = "\(window.level.rawValue)  (아이콘 \(desktopIcon) · 일반 \(normal))"

        let screen = window.screen ?? NSScreen.main
        screenDescription = screen?.localizedName ?? "없음"

        let frame = window.frame
        frameDescription = String(
            format: "%.0f, %.0f · %.0f×%.0f",
            frame.origin.x, frame.origin.y, frame.width, frame.height
        )
    }
}

// MARK: - 뷰

private struct SpikeCard: View {
    let probe: WindowProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 9) {
                row("창 레벨", probe.levelDescription)
                row("디스플레이", probe.screenDescription)
                row("좌표·크기", probe.frameDescription)
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 9) {
                row("Space 전환", "\(probe.spaceChanges) 회")
                row("디스플레이 변경", "\(probe.screenChanges) 회")
                row("마지막 이벤트", probe.lastEvent)
            }

            Spacer(minLength: 4)

            Text("Mission Control · Stage Manager · 월페이퍼 클릭을 눌러 보고, 이 창이 사라지는지 확인하세요. 드래그로 옮길 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.title3)
                .foregroundStyle(.tint)
            Text("바탕화면 창 스파이크")
                .font(.headline)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }
}
