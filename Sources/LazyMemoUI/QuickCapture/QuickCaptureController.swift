import AppKit
import LazyMemoCore
import SwiftUI

/// 빠른 입력의 표시와 지연 측정 (설계문서 §8, §11).
///
/// 목표는 **단축키에서 커서까지 150ms**다. 그래서 창과 뷰를 앱 기동 시 미리
/// 만들어 두고 위치와 표시만 토글한다 — 처음 여는 순간에 SwiftUI 계층을 짓게
/// 두면 첫 호출이 눈에 띄게 느리고, 그 한 번이 사용자의 인상을 정한다.
///
/// **적던 글은 어떻게 닫아도 잃지 않는다.** esc 로 닫든 다른 앱으로 넘어가든
/// 상자가 기억하고 있다가 다시 열 때 돌려준다.
///
/// 닫을 때 저장해 버리는 쪽도 해 봤지만 안 된다 — 이 상자는 검색을 겸하므로
/// 메모를 찾으려고 친 낱말이 새 메모가 되어 쌓인다. 버리지도, 저장하지도
/// 않고 **들고 있는 것**이 유일하게 맞는 답이다.
@MainActor
final class QuickCaptureController {
    /// 말풍선 너비. 메뉴바 아이콘에 매다는 것이라 화면 한가운데 띄울 때보다 좁다.
    static let width: CGFloat = 440

    private let panel: QuickCapturePanel
    private let hosting: NSHostingView<QuickCaptureView>
    private let model: QuickCaptureModel
    private let store: MemoStore
    private let windows: NoteWindowManager

    /// 말풍선을 매달 자리를 물어본다. 메뉴바 아이콘이 어디 있는지는
    /// `MenuBarController` 만 알고, 아이콘은 숨겨질 수도 있다.
    var anchorProvider: () -> NSRect? = { nil }

    /// 마지막 표시에 걸린 시간. 성능 예산 검증용이다.
    private(set) var lastLatency: Duration?

    /// 상자가 열려 있는 동안만 사는 바깥 클릭 감시자.
    private var outsideClickMonitor: Any?

    init(store: MemoStore, windows: NoteWindowManager) {
        self.store = store
        self.windows = windows
        self.model = QuickCaptureModel(store: store)

        let initialSize = NSSize(width: Self.width, height: 120)
        self.panel = QuickCapturePanel(contentRect: NSRect(origin: .zero, size: initialSize))

        var commit: () -> Void = {}
        var cancel: () -> Void = {}
        self.hosting = NSHostingView(rootView: QuickCaptureView(
            model: model,
            onCommit: { commit() },
            onCancel: { cancel() }
        ))
        // 높이는 줄 수와 결과 수에 따라 달라진다. 뷰가 창 크기를 정하게 두되 가로는 고정한다.
        hosting.sizingOptions = [.intrinsicContentSize]

        panel.contentView = hosting
        commit = { [weak self] in self?.commit() }
        cancel = { [weak self] in self?.close() }

        // 줄이 늘거나 결과가 바뀌면 창 높이가 따라가야 한다.
        model.onLayoutChange = { [weak self] in self?.resize() }

        // loadView 와 첫 레이아웃을 지금 치른다 — 이것이 프리워밍의 실체다.
        hosting.layoutSubtreeIfNeeded()
    }

    var isOpen: Bool { panel.isVisible }

    /// 표준 편집 단축키가 실제로 글 쓰는 곳까지 닿는지 확인한다.
    ///
    /// 메인 메뉴가 없으면 ⌘A 는 어디에도 도달하지 못한다 (`StandardMenu`).
    /// 사람이 눌러 보기 전에는 드러나지 않는 종류라, 가짜 이벤트를 만들어
    /// 메뉴에 직접 흘려보내고 선택 범위가 실제로 잡히는지 본다.
    func selectAllReach() -> String {
        guard let textView = panel.contentView?.firstTextView else { return "텍스트 뷰 없음" }
        textView.string = "치과 예약"
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ) else { return "이벤트 생성 실패" }

        let handled = NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
        let selected = textView.selectedRange().length
        textView.string = ""
        return "메뉴처리=\(handled) 선택된길이=\(selected)"
    }

    /// 상자가 왜 안 보이는지 밖에서 들여다보기 위한 것 (`verify-capture.sh`).
    var diagnostics: String {
        "visible=\(panel.isVisible) key=\(panel.isKeyWindow) level=\(panel.level.rawValue) "
            + "hidesOnDeactivate=\(panel.hidesOnDeactivate) appActive=\(NSApp.isActive) "
            + "frame=\(NSStringFromRect(panel.frame))"
    }

    func toggle() {
        isOpen ? close() : show()
    }

    func show() {
        let started = ContinuousClock.now

        model.prepareForShow()
        resize()
        model.arrowOffset = panel.moveToCaptureAnchor(below: anchorProvider())

        // 상주 앱(.accessory)은 스스로 활성화해야 키 입력을 받는다.
        // 창을 올리기 **전에** 활성화해야 첫 글자를 놓치지 않는다.
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        focusEditor()
        watchForOutsideClicks()

        lastLatency = ContinuousClock.now - started
    }

    /// 상자 바깥을 누르면 치운다.
    ///
    /// 앱이 끝내 활성화되지 못하면 `didResignActiveNotification` 이 오지 않아
    /// 상자가 남는다. 전역 클릭 감시가 그 구멍을 메운다 — 권한이 필요 없는
    /// 종류(`addGlobalMonitorForEvents`)라 "설정으로 보내지 않는다" 원칙도 지킨다.
    private func watchForOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isOpen else { return }
                self.close(returningFocus: false)
            }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    /// 상자를 치운다. **적던 것은 상자가 기억한다** (`prepareForShow`).
    ///
    /// - Parameter returningFocus: 하던 앱으로 키보드를 돌려줄지.
    ///   상주 앱은 상자를 띄우려고 스스로 활성화했으므로, 그냥 숨기기만 하면
    ///   보이는 창이 하나도 없는 채로 앱이 활성 상태로 남는다. 그 다음 타자는
    ///   허공으로 간다. 메모를 열어 보여줄 때만 예외다.
    func close(returningFocus: Bool = true) {
        stopWatchingOutsideClicks()
        panel.orderOut(nil)
        if returningFocus, NSApp.isActive { NSApp.deactivate() }
    }

    /// 검색 결과가 늘고 줄 때, 글이 여러 줄이 될 때 창 높이를 따라가게 한다.
    func resize() {
        let fitting = hosting.fittingSize
        let height = max(fitting.height, 96)
        panel.setContentSize(NSSize(width: Self.width, height: height))
        // 아래로 자라면 아이콘에서 멀어진다. 위쪽 모서리를 붙잡아 둔다.
        model.arrowOffset = panel.moveToCaptureAnchor(below: anchorProvider())
    }

    /// 커서가 서 있어야 "표시됐다"고 할 수 있다 (§8).
    ///
    /// 남아 있던 초안은 **전부 선택된 채로** 선다. 그냥 치면 덮어쓰고,
    /// 이어 쓰려면 → 한 번이면 된다. 지우고 시작하라고 요구하지 않는다.
    private func focusEditor() {
        guard let textView = panel.contentView?.firstTextView else { return }
        panel.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: (textView.string as NSString).length))
    }

    // 앱이 비활성화될 때 닫는 규칙은 **버렸다.**
    //
    // 포커스는 사용자가 아닌 것들 때문에도 튄다 — 다른 앱이 잠깐 앞으로 나오는
    // 것만으로 상자가 사라졌다. 실측하니 상자를 띄운 지 1초 안에 활성화가
    // 되돌아가면서 스스로 닫혔고, 사용자에게는 "눌러도 안 뜬다" 로 보였다.
    // 유예 시간을 두는 것도 시도했지만 튕김이 그보다 늦게 오면 똑같았다.
    //
    // 그래서 닫는 길을 **사람이 한 일**로만 한정한다: esc, ⌘⏎, 단축키·아이콘
    // 다시 누르기, 그리고 상자 바깥 클릭. 적고 있는 상자는 어떤 잡음으로도
    // 사라지지 않는다.

    /// ⌘⏎ — 적기 끝.
    private func commit() {
        switch model.commit() {
        case .create(let draft):
            // 적고 하던 일로 돌아간다. 메모 창은 바탕화면 높이에 있어서
            // 여기서 활성화하면 **보이지 않는 창으로 키보드가 넘어가고**
            // 이어서 친 글자가 사라진다.
            model.clear()
            close()
            Task {
                guard let memo = try? await store.create(
                    body: draft.text, due: draft.due, at: draft.at
                ) else { return }
                windows.announce(memo)
            }

        case .open(let id):
            // 여기서는 사용자가 "그 메모를 보자" 고 한 것이다. 앞으로 데려온다.
            model.clear()
            close(returningFocus: false)
            windows.reveal(id)

        case .nothing:
            close()
        }
    }
}
