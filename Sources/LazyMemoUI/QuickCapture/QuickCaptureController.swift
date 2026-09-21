import AppKit
import LazyMemoAssistant
import LazyMemoAssistantUI
import LazyMemoCore
import LazyMemoPlaces
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
    /// 빈 상자도 이만큼은 된다. 한 줄짜리 상자가 쪽지처럼 얇아 보이지 않게.
    private static let minimumHeight: CGFloat = 96

    private let panel: QuickCapturePanel
    private let hosting: CaptureHostingView
    private let model: QuickCaptureModel
    private let store: MemoStore
    private let windows: NoteWindowManager

    /// 말풍선을 매달 자리를 물어본다. 메뉴바 아이콘이 어디 있는지는
    /// `MenuBarController` 만 알고, 아이콘은 숨겨질 수도 있다.
    var anchorProvider: () -> NSRect? = { nil }

    /// 방금 적은 것이 일정이었다고 달력에 알린다.
    ///
    /// 달력 창을 여기서 직접 들고 있지 않는 이유는 `anchorProvider` 와 같다 —
    /// 창을 누가 소유하는지는 `MenuBarController` 만 안다.
    var onScheduled: (CalendarDate) -> Void = { _ in }

    /// 마지막 표시에 걸린 시간. 성능 예산 검증용이다.
    private(set) var lastLatency: Duration?

    /// 상자가 열려 있는 동안만 사는 바깥 클릭 감시자.
    ///
    /// **바깥은 두 종류다** — 다른 앱, 그리고 이 앱의 다른 창(바탕화면 메모).
    /// 감시하는 길이 서로 달라서 둘을 나란히 건다.
    private var outsideClickMonitors: [Any] = []

    /// 상자가 열려 있는 동안만 사는 ⌘ 조합 감시자.
    ///
    /// **⌘V 가 죽는 마지막 구멍이 여기였다.** `NSApp.sendEvent` 는 ⌘ 조합을
    /// **키 윈도**의 `performKeyEquivalent` 에만 흘려보낸다. 그런데 이 상자는
    /// `.nonactivatingPanel` 이고 `NSApp.activate()` 는 비동기라 — 게다가
    /// macOS 가 활성화를 거절하기도 한다 — 상자가 키 윈도가 아닌 채로 서
    /// 있는 순간이 실제로 있다. 그때 `NSApp.keyWindow` 는 nil 이므로 그
    /// 호출이 **아예 일어나지 않고**, 텍스트 뷰가 ⌘V 를 아무리 잘 처리해도
    /// 이벤트가 거기까지 오지 않는다.
    ///
    /// 평범한 글자는 `event.window` 로 곧장 가므로 멀쩡히 들어간다. 그래서
    /// 사용자에게는 정확히 **"글자는 쳐지는데 사진만 안 붙는다"** 로 보였다
    /// (`verify-capture-paste.sh` 가 그 두 가지를 나란히 잰다).
    ///
    /// 지역 감시는 `NSApp.sendEvent` **앞에** 서므로 키 윈도 여부와 무관하게
    /// 같은 길이 된다. 우리가 처리한 이벤트는 삼키므로 상자가 키일 때도
    /// 두 번 붙지 않는다.
    private var editingKeyMonitor: Any?

    init(store: MemoStore, windows: NoteWindowManager, draft: CaptureDraftStore? = nil, settings: SettingsStore? = nil) {
        self.store = store
        self.windows = windows
        self.model = QuickCaptureModel(
            store: store,
            lastOpened: { [weak windows] id in windows?.lastOpened(id) },
            draft: draft
        )
        // 약속을 적으면 가는 길을 묻는다 — 설정이 없는 자리(시험·렌더)에서는 묻지 않는다.
        if let settings {
            let planner = RoutePlanner(store: store, settings: { settings.current })
            model.planner = planner
        }

        let initialSize = NSSize(width: Self.width, height: 120)
        self.panel = QuickCapturePanel(contentRect: NSRect(origin: .zero, size: initialSize))

        var commit: () -> Void = {}
        var ask: () -> Void = {}
        var cancel: () -> Void = {}
        self.hosting = CaptureHostingView(rootView: QuickCaptureView(
            model: model,
            onCommit: { commit() },
            onAsk: { ask() },
            onCancel: { cancel() },
            // 목록의 점이 찬 점인지 빈 점인지는 창을 들고 있는 쪽만 안다.
            isOnDesktop: { [weak windows] id in windows?.isVisible(id) ?? false }
        ))
        // 높이는 줄 수와 결과 수에 따라 달라진다. 뷰가 창 크기를 정하게 두되 가로는 고정한다.
        hosting.sizingOptions = [.intrinsicContentSize]

        panel.contentView = hosting
        commit = { [weak self] in self?.commit() }
        ask = { [weak self] in self?.ask() }
        cancel = { [weak self] in self?.close() }
        // 길을 다 적었다 — 상자는 닫히고 달력이 그 날을 보인다 (적은 것이 곧 나온다, §8).
        model.planner?.onWritten = { [weak self] memo, _ in
            self?.close()
            self?.announce(memo)
        }

        // 줄이 늘거나, 결과가 바뀌거나, 날짜 칩이 뜨면 창이 따라가야 한다.
        // **뷰가 실제로 다시 그려진 그 자리에서** 알려 온다 — 모델 쪽에서
        // "이쯤이면 커졌겠지" 하고 부르던 길만 두었을 때 날짜 칩이 빠졌다.
        hosting.onContentHeightChange = { [weak self] _ in self?.resize() }

        // loadView 와 첫 레이아웃을 지금 치른다 — 이것이 프리워밍의 실체다.
        hosting.layoutSubtreeIfNeeded()
    }

    var isOpen: Bool { panel.isVisible }

    /// 시험이 상자 속을 들여다보는 창구.
    ///
    /// 붙여넣기가 **실제 상자까지 닿는지**는 창과 텍스트 뷰가 다 선 채로만
    /// 확인할 수 있다 — ⌘V 가 죽던 자리가 바로 그 사이였다.
    var editorForTesting: MemoNSTextView? {
        panel.contentView?.firstTextView as? MemoNSTextView
    }

    /// 글 상자에 커서를 세운다. 표준 편집 단축키는 편집 중일 때만 산다.
    func focusForTesting() {
        focusEditor()
    }

    /// 지금 상자가 들고 있는 것.
    var draftForTesting: String { model.query }
    /// 지금 상자에 붙어 있는 사진.
    var imagesForTesting: [AttachedImage] { model.images }

    /// 앱이 끝나기 직전 — 들고 있던 글을 기다리지 않고 적는다.
    func flushDraft() { model.flushDraft() }

    /// ⌘⏎ 를 누른 것과 같다 — 소개 영상 주행(`DemoTour`)이 부른다.
    func commitForDemo() { commit() }

    /// 소개 영상 — 가는 길 되물음이 어디까지 왔나, 그리고 탈것 고르기.
    var routeStepForDemo: RoutePlanner.Step? { model.planner?.step }
    var queryForDemo: String { model.query }
    func chooseRouteForDemo(_ kind: String) { model.planner?.choose(kind) }

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
            + "frame=\(NSStringFromRect(panel.frame)) draft=\(model.query.count)자"
    }

    func toggle() {
        CaptureTrace.log("toggle isOpen=\(isOpen) visible=\(panel.isVisible) 활성Space=\(panel.isOnActiveSpace) 앱활성=\(NSApp.isActive) 비켜섬=\(isParked)")
        if !isOpen { show(); return }
        // 답을 든 채 비켜 서 있는 상자에 단축키·아이콘은 「돌아오기」다 — 닫는 것이 아니라. 닫으려면 그 안에서 esc·×.
        isParked ? refocus() : close()
    }

    /// 바깥 클릭에 손을 내주고 서 있는 중인가 — 마지막 손짓이 「들고 있는 상자의 바깥을 누른 것」이었다.
    /// 상자를 누르거나 `refocus` 로 돌아오면 풀린다. 키 윈도 여부는 보지 않는다 — 활성화는 비동기라
    /// 그 값은 순간마다 다르고, 사람이 한 일(바깥 클릭)만이 믿을 수 있는 기준이다.
    private var isParked: Bool { isOpen && model.parked }

    /// 비켜 서 있던 상자로 돌아온다 — 답은 그대로, 커서는 글 칸에.
    private func refocus() {
        model.parked = false
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        focusEditor()
        CaptureTrace.log("refocus key=\(panel.isKeyWindow) 앱활성=\(NSApp.isActive)")
    }

    func show() {
        let started = ContinuousClock.now

        model.prepareForShow()
        model.parked = false
        resize()

        // 상주 앱(.accessory)은 스스로 활성화해야 키 입력을 받는다.
        // 창을 올리기 **전에** 활성화해야 첫 글자를 놓치지 않는다.
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        focusEditor()
        watchForOutsideClicks()

        lastLatency = ContinuousClock.now - started
        CaptureTrace.log("show 뒤 visible=\(panel.isVisible) key=\(panel.isKeyWindow) 활성Space=\(panel.isOnActiveSpace) 앱활성=\(NSApp.isActive) frame=\(NSStringFromRect(panel.frame)) 앵커=\(anchorProvider().map(NSStringFromRect) ?? "없음")")
    }

    /// 상자 바깥을 누르면 치운다.
    ///
    /// 앱이 끝내 활성화되지 못하면 `didResignActiveNotification` 이 오지 않아
    /// 상자가 남는다. 클릭 감시가 그 구멍을 메운다 — 권한이 필요 없는
    /// 종류라 "설정으로 보내지 않는다" 원칙도 지킨다.
    ///
    /// **감시는 둘이어야 한다.** `addGlobalMonitorForEvents` 는 **다른 앱으로
    /// 가는** 클릭만 본다. 그런데 이 앱의 바깥에는 바탕화면 메모 창들이 있다 —
    /// 메모를 고치다 단축키로 상자를 열고 도로 메모를 누르면, 그 클릭은 우리
    /// 앱이 받으므로 전역 감시에 잡히지 않고 **상자가 그대로 남았다.**
    /// 앱 안쪽을 보는 지역 감시가 그 절반을 맡는다.
    private func watchForOutsideClicks() {
        guard outsideClickMonitors.isEmpty else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        // 다른 앱 — 바탕화면, 브라우저, 무엇이든.
        let elsewhere = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.outsideClicked(event) }
        })

        // 우리 앱의 다른 창 — 메모 창, 달력, 설정.
        // 이벤트는 그대로 흘려보낸다. 상자를 치우는 것과 메모에 커서를 놓는
        // 것은 한 번의 클릭으로 같이 일어나야 한다.
        let ours = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event -> NSEvent? in
            MainActor.assumeIsolated { self?.outsideClicked(event) }
            return event
        })

        outsideClickMonitors = [elsewhere, ours].compactMap { $0 }

        editingKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event -> NSEvent? in
            let handled = MainActor.assumeIsolated {
                guard let self, self.isOpen else { return false }
                return self.handles(event)
            }
            // 우리가 처리했으면 삼킨다 — 상자가 키일 때 창까지 흘러가면 두 번 붙는다.
            return handled ? nil : event
        }
    }

    /// 이 ⌘ 조합을 상자의 글 상자가 맡아야 하는가. 맡았으면 `true`.
    ///
    /// 상자 밖으로는 손대지 않는다 — 메모 창이 키일 때의 ⌘C 까지 여기서
    /// 가로채면, 고치는 곳은 하나인데 영향은 앱 전체로 번진다.
    ///
    /// 비공개가 아닌 이유는 `handle(command:in:)` 과 같다 — **키가 어디로
    /// 가는지는 화면에 안 보인다.** 시험이 직접 부른다.
    func handles(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.window == nil || event.window === panel,
              let editor = panel.contentView?.firstTextView as? MemoNSTextView,
              panel.firstResponder === editor
        else { return false }
        return editor.performKeyEquivalent(with: event)
    }

    /// 클릭 한 번 — 상자 안이면 「돌아왔다」, 바깥이면 들고 있는 것이 없을 때만 치우고 있으면 **비켜 선다.**
    ///
    /// 비켜 선다는 것은: 상자는 그 자리에 그대로(떠 있는 창이라 다른 앱 위에 남는다), 손은 누른 곳으로 간다.
    /// 「달러 환율 얼마야?」를 묻고 브라우저를 눌렀다고 답을 버리면, 사람은 답을 받으려고 상자만 바라보고 있어야
    /// 한다 — 게으른 사람은 그러지 않는다. 답은 오면 거기 서 있고, 단축키나 상자 클릭으로 돌아온다.
    private func outsideClicked(_ event: NSEvent) {
        guard isOpen else { return }
        let inside = event.window === panel
        if inside { model.parked = false; return }
        guard Self.dismissesCapture(insidePanel: false, at: Self.screenPoint(of: event), anchor: anchorProvider()) else { return }
        if model.holdsWork {
            guard !model.parked else { return }
            model.parked = true
            CaptureTrace.log("바깥 클릭 — 들고 있어 비켜 섬 busy=\(model.assistant?.isBusy ?? false) standing=\(model.assistant?.isStanding ?? false) asking=\(model.isAsking)")
            return
        }
        close(returningFocus: false)
    }

    /// 클릭한 자리를 화면 좌표로. 다른 앱으로 간 클릭은 창이 없으므로
    /// `locationInWindow` 가 이미 화면 좌표다.
    private static func screenPoint(of event: NSEvent) -> NSPoint {
        guard let window = event.window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    /// 치울지 말지의 판단만 떼어 둔 것 — 창 없이도 검증할 수 있게.
    ///
    /// - Parameters:
    ///   - insidePanel: 클릭이 상자 자신에게 갔는가.
    ///   - point: 클릭한 화면 좌표.
    ///   - anchor: 메뉴바 아이콘 자리. 아이콘은 **스스로 토글한다** — 여기서
    ///     먼저 닫아 버리면 이어지는 클릭이 도로 열어 깜빡이기만 한다.
    ///   - holding: 상자가 잃을 것을 들고 있는가 (`QuickCaptureModel.holdsWork`). 들고 있으면
    ///     바깥 클릭은 치우지 않는다 — 비켜 설 뿐이다 (`outsideClicked`).
    static func dismissesCapture(insidePanel: Bool, at point: NSPoint, anchor: NSRect?, holding: Bool = false) -> Bool {
        if insidePanel || holding { return false }
        if let anchor, anchor.contains(point) { return false }
        return true
    }

    private func stopWatchingOutsideClicks() {
        outsideClickMonitors.forEach(NSEvent.removeMonitor)
        outsideClickMonitors.removeAll()
        if let editingKeyMonitor { NSEvent.removeMonitor(editingKeyMonitor) }
        editingKeyMonitor = nil
    }

    /// 바깥 클릭이 상자를 치우고 안쪽 클릭은 놔두는지 확인한다
    /// (`verify-capture-dismiss.sh`).
    ///
    /// 클릭을 프로그램으로 만들어 내려면 손쉬운 사용 권한이 필요하다. 그래서
    /// **우리 앱의 이벤트 큐에 가짜 클릭을 직접 넣는다** — 지역 감시가 보는
    /// 자리는 사람이 누른 것과 같다. 바탕화면 메모 창 역할은 화면 밖에 세운
    /// 임시 창이 대신한다.
    func dismissReach() async -> String {
        let standIn = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: 200, height: 140),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        standIn.orderFront(nil)
        defer { standIn.orderOut(nil) }

        show()
        // 감시가 둘 다 걸렸는지 — 하나라도 nil 이면 그쪽 바깥은 안 닫힌다.
        let watching = outsideClickMonitors.count
        let opened = isOpen
        await postClick(toWindow: panel.windowNumber)
        let afterInside = isOpen
        await postClick(toWindow: standIn.windowNumber)
        let afterOutside = isOpen
        close()

        // 답을 든 채라면 바깥 클릭은 치우지 않고 비켜 선다 (2026-09-21).
        var holdingLine = "비서없음"
        if let assistant = model.assistant {
            show()
            let hit = Evidence(hit: WebHit(title: "환율", url: URL(string: "https://www.example.org/fx")!, snippet: "1,386원"))
            let answer = AssistantAnswer(found: true, text: "1,386원 근처입니다", evidence: [hit.memoID], quotes: ["1,386원"],
                                         sources: [WebSource(id: hit.memoID, title: "환율", url: hit.url!)])
            assistant.stageForPreview(answer: answer, results: [hit], question: "달러 환율 얼마야?")
            await postClick(toWindow: standIn.windowNumber)
            let keptOpen = isOpen
            let parked = model.parked
            // 돌아오기 — 단축키의 길. 답은 그대로.
            toggle()
            let backAndStanding = isOpen && !model.parked && assistant.isStanding
            close()
            holdingLine = "답들고바깥클릭뒤열림=\(keptOpen) 비켜섬=\(parked) 단축키로돌아옴=\(backAndStanding)"
        }

        return "감시=\(watching) 열림=\(opened) 안쪽클릭뒤열림=\(afterInside) 바깥클릭뒤열림=\(afterOutside) \(holdingLine)"
    }

    /// ⌘⌫ 가 **고른 줄까지** 닿는지 (`verify-capture-delete.sh`).
    ///
    /// 키가 어디로 가는지는 화면에 나타나지 않는다 — 메모 대신 글자가 지워져도
    /// 그림은 똑같고, 렌더로도 잡히지 않는다. 그래서 가짜 키를 눌러 보고
    /// **메모가 휴지통으로 갔는지, 적던 글은 그대로인지** 둘 다 본다.
    ///
    /// 글은 반드시 모델을 거쳐 넣는다. 텍스트 뷰에 직접 꽂으면 다시 그릴 때
    /// 모델의 글이 되밀려(`MemoTextSync`) 우리가 넣은 글이 사라지고, 그것이
    /// "⌘⌫ 가 글자를 지웠다" 로 잘못 읽힌다 — 처음 이 진단을 붙였을 때 실제로
    /// 그렇게 나왔다.
    ///
    /// 확인용 메모 한 장은 휴지통에 남는다. 30일 뒤 저절로 지워진다 (D6).
    func deleteReach() async -> String {
        guard let target = try? await store.create(body: "지우기 확인용") else {
            return "메모 못 만듦"
        }
        show()

        // 찾아 놓고 지운다. 이 낱말은 방금 만든 메모에 걸리고, 글이 있는
        // 채로 눌러야 "메모 대신 글자를 지웠다" 를 잡아낼 수 있다.
        let typed = "지우기"
        model.query = typed
        try? await Task.sleep(for: .milliseconds(400))

        guard model.listed.first?.id == target.id else {
            close(returningFocus: false)
            return "목록에 안 올라옴 찾은수=\(model.listed.count)"
        }
        model.selection = 0

        guard let textView = panel.contentView?.firstTextView else {
            close(returningFocus: false)
            return "텍스트 뷰 없음"
        }

        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "\u{7f}", charactersIgnoringModifiers: "\u{7f}",
            isARepeat: false, keyCode: 51
        ) else {
            close(returningFocus: false)
            return "이벤트 생성 실패"
        }

        textView.keyDown(with: event)
        // 지우기는 파일을 옮기는 일이라 비동기다. 옮겨질 때까지만 기다린다.
        try? await Task.sleep(for: .milliseconds(300))

        let moved = store.trash.contains { $0.id == target.id }
        let kept = model.query == typed && textView.string == typed
        let undoable = model.lastDeleted?.id == target.id
        close(returningFocus: false)

        return "지움=\(moved) 글유지=\(kept) 되돌릴수있음=\(undoable)"
    }

    /// ⌘V 가 **사람이 누른 것과 같은 길로** 글 상자까지 닿는지
    /// (`verify-capture-paste.sh`).
    ///
    /// 시험(`CapturePasteTests`)은 텍스트 뷰의 `performKeyEquivalent` 를 직접
    /// 부른다. 그 함수가 하는 일은 지키지만 **키가 거기까지 오는지**는 재지
    /// 못한다 — 사람이 누른 ⌘V 는 앱 → 창 → 뷰 계층을 타고 내려오므로 그
    /// 사이 어디가 끊겨도 시험은 초록이고 화면에서는 아무 일도 안 난다.
    /// "아직도 사진이 안 붙는다" 가 그 자리에 살고 있었다.
    ///
    /// **두 번 잰다.** 상자가 키 윈도일 때와 아닐 때다. 아닐 때가 결함이
    /// 살던 세상인데, 활성화는 비동기라 그냥 재면 어느 쪽이 걸릴지 그때그때
    /// 다르다 — 그래서 한 번은 앱을 일부러 비활성으로 만들어 놓고 잰다.
    func pasteReach() async -> String {
        let types = NSPasteboard.general.types?.map(\.rawValue).joined(separator: " ") ?? "없음"
        let withoutKey = await pasteRound(deactivating: true)
        let withKey = await pasteRound(deactivating: false)
        return "붙임판=[\(types)] 키윈도없이{\(withoutKey)} 키윈도로{\(withKey)}"
    }

    /// 한 번의 ⌘V. `deactivating` 이면 앱을 비활성으로 만들어 키 윈도를 없앤다.
    private func pasteRound(deactivating: Bool) async -> String {
        model.clear()
        show()
        // 활성화는 비동기다. 자리 잡을 틈을 준다.
        try? await Task.sleep(for: .milliseconds(600))
        if deactivating {
            NSApp.deactivate()
            // **시간이 아니라 상태를 기다린다.**
            //
            // 400ms 고정으로 기다리고 있었다. 비활성화는 비동기라 그 안에
            // 물러날 때도 있고 아닐 때도 있었고, 그래서 이 진단은 **같은
            // 나무에서 다섯 번 중 둘이 빨갛게** 나왔다 — 재려던 세상(비활성)이
            // 아니라 그때그때 다른 세상을 재고 있었던 것이다.
            //
            // 그 깜빡임이 실제로 한 번 «회귀» 로 오인돼 두 세션의 시간을
            // 먹었다. 검증 스크립트가 가끔 빨간 것은 초록보다 나쁘다 —
            // 사람이 그것을 믿지 않게 되거나, 없는 결함을 쫓게 된다.
            for _ in 0..<80 {
                if !NSApp.isActive { break }
                try? await Task.sleep(for: .milliseconds(25))
            }
            // 물러난 뒤에도 창 서열이 정리될 틈은 한 박자 준다.
            try? await Task.sleep(for: .milliseconds(120))
        }

        guard let textView = panel.contentView?.firstTextView as? MemoNSTextView else {
            close(returningFocus: false)
            return "텍스트 뷰 없음"
        }
        let focused = panel.firstResponder === textView
        let key = panel.isKeyWindow

        // 먼저 **맨 글자**를 보낸다. 글자는 들어가는데 ⌘V 만 죽는 것인지,
        // 아니면 키가 통째로 안 오는 것인지 — 사용자가 보는 증상이 갈리는
        // 자리가 여기다.
        if let plain = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "ㄱ", charactersIgnoringModifiers: "ㄱ", isARepeat: false, keyCode: 4
        ) {
            NSApp.sendEvent(plain)
        }
        try? await Task.sleep(for: .milliseconds(120))
        let typed = !model.query.isEmpty

        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9
        ) else {
            close(returningFocus: false)
            return "이벤트 생성 실패"
        }

        NSApp.sendEvent(event)
        // 파일을 쓰고 그 결과가 모델까지 오는 데 한 박자 걸린다.
        try? await Task.sleep(for: .milliseconds(250))

        let references = MarkdownScanner.imagePaths(in: model.query)
        let onDisk = !references.isEmpty && references
            .compactMap { store.attachments.url(for: $0) }
            .allSatisfy { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }

        close(returningFocus: false)
        return "커서=\(focused) 키윈도=\(key) 글자=\(typed) "
            + "넣음=\(references.count) 조각=\(model.images.count) 파일=\(onDisk)"
    }

    private func postClick(toWindow number: Int) async {
        guard let event = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: number,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ) else { return }
        NSApp.postEvent(event, atStart: true)
        try? await Task.sleep(for: .milliseconds(150))
    }

    /// 상자를 치운다. **적던 것은 상자가 기억한다** (`prepareForShow`).
    ///
    /// - Parameter returningFocus: 하던 앱으로 키보드를 돌려줄지.
    ///   상주 앱은 상자를 띄우려고 스스로 활성화했으므로, 그냥 숨기기만 하면
    ///   보이는 창이 하나도 없는 채로 앱이 활성 상태로 남는다. 그 다음 타자는
    ///   허공으로 간다. 메모를 열어 보여줄 때만 예외다.
    func close(returningFocus: Bool = true) {
        model.target = nil
        // 결과 카드는 닫히면 끝이다 — 권한 것을 안 누른 것도 답이다.
        model.dismissLeft()
        // 가는 길을 묻던 중에 닫으면 「됐어」와 같다 — 메모는 이미 적혔다.
        model.planner?.dismiss()
        model.planner?.acknowledge()
        // 되묻기 중에 닫으면 「시각 없이」와 같다 — 이미 ⌘⏎ 로 적으라 한 글이다 (설계 D12).
        if let draft = model.takePendingDraft() {
            Task {
                guard let memo = try? await store.create(
                    body: draft.body ?? "", due: draft.due.value, at: draft.at.value,
                    place: draft.place, geo: draft.geo
                ) else { return }
                announce(memo)
            }
        }
        // **닫은 상자는 빈 손으로 다시 열린다.** 읽던 중이면 그만두고(reset 이 먼저 cancel 한다), 서 있던
        // 답·결과 카드는 내린다 — 지난번 웹의 답이 다음 열림에 도로 서 있으면 그것은 지금 하려는 일이
        // 아니라 아까 한 일이고, 치우는 길도 없었다 (2026-09-18 사용자). 되돌리기는 메뉴가 들고 있다.
        model.assistant?.reset()
        CaptureTrace.log("close 돌려줌=\(returningFocus) visible=\(panel.isVisible)")
        stopWatchingOutsideClicks()
        panel.orderOut(nil)
        // 닫는 순간이 곧 «기억한다» 의 순간이다. 미뤄 둔 쓰기를 지금 한다.
        model.flushDraft()
        if returningFocus, NSApp.isActive { NSApp.deactivate() }
    }

    /// 검색 결과가 늘고 줄 때, 글이 여러 줄이 될 때, 날짜 칩이 뜰 때
    /// 창을 내용에 맞춘다.
    ///
    /// 크기와 자리를 **한 번에** 넘긴다. 나눠 하면 상자가 위로 자랐다가
    /// 제자리로 돌아오는 중간 상태가 화면에 나온다 (`moveToCaptureAnchor`).
    func resize() {
        let height = max(hosting.fittingSize.height, Self.minimumHeight)
        model.arrowOffset = panel.moveToCaptureAnchor(
            below: anchorProvider(), contentHeight: height
        )
    }

    /// 상자가 지금 어떤 자리에 어떤 크기로 서 있는지. 테스트가 읽는다.
    var placement: (frame: NSRect, contentHeight: CGFloat) {
        (panel.frame, hosting.fittingSize.height)
    }

    /// 사람이 친 것처럼 글을 넣고, 화면 갱신을 기다리지 않고 배치까지 마친다.
    ///
    /// 날짜 칩은 **타자와 함께** 뜬다. 검색이 돌아오기를 기다린 뒤에 재면
    /// 사용자가 실제로 보는 그 순간을 놓치므로, 시험은 여기로 들어온다.
    func typeForTesting(_ text: String) {
        model.query = text
        // 창을 여기서 다시 재지 **않는다.** 뷰가 스스로 알려 오는 길
        // (`CaptureHostingView`)이 살아 있는지가 이 시험의 요점이다.
        hosting.layoutSubtreeIfNeeded()
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

    /// 이 기기의 비서를 상자에 끼운다 — 묻기·시키기가 이 상자에서 된다.
    func adoptAssistant(_ assistant: AssistantModel?) {
        model.assistant = assistant
        assistant?.onSettled = { [weak self] in self?.model.reflectAssistant() }
    }

    /// 「이 메모에게 시키기…」 — 그 메모를 대상으로 상자를 연다.
    func show(target: ULID) {
        model.target = target
        show()
    }

    /// 밖에서 들어온 약속 메모 — 상자를 열고 **결과 카드로 권한다** (`InboundDoor.onRouteAsk`). 묻지 않는다:
    /// 「어디서 출발하시나요?」가 상자를 차지하면 다음에 치는 글이 그 답이 된다. 카드의 「가는 길 찾기」를 누르면 그때 묻는다.
    /// 상자가 다른 되물음 중이면 끼어들지 않는다.
    func askRoute(_ memo: Memo) {
        guard let planner = model.planner, !planner.isActive, model.pendingQuestion == nil else { return }
        show()
        model.offerRoute(for: memo)
    }

    /// ⌘⏎ — 적기 끝.
    private func commit() {
        switch model.commit() {
        case .create(let draft):
            // **적힌 뒤에** 비우고 닫는다. 앞선 판은 먼저 비우고 닫은 뒤 적었는데, 그러면 저장이
            // 실패한 순간 글은 이미 없다 — 「적었는데 없다」가 되고, 저장 버튼 없는 앱에서 그것은
            // 한 번으로 끝이다. 실패하면 상자는 열린 채 글을 들고 그 까닭을 적는다 (`saveTrouble`).
            // 적는 것은 한 박자라 사람은 차이를 못 느낀다.
            Task {
                guard let memo = await model.save({
                    try await store.create(body: draft.text, due: draft.due, at: draft.at)
                }) else { return }
                left(memo)
            }

        case .compose(let patch):
            // 같은 길 — 다만 비서의 파서가 자리·좌표까지 읽어 왔다.
            Task {
                guard let memo = await model.save({
                    try await store.create(
                        body: patch.body ?? "", due: patch.due.value, at: patch.at.value,
                        place: patch.place, geo: patch.geo
                    )
                }) else { return }
                left(memo)
            }

        case .setTime(let id, let at):
            // 결과 카드의 「시각 정하기」에 온 답 — 그 메모에 적는다. 새 메모가 아니다.
            Task {
                guard let memo = await model.save({ try await store.update(id, at: .some(at)) }) else { return }
                model.clear()
                close()
                announce(memo)
            }

        case .routeReply(let text):
            model.query = ""
            model.planner?.reply(text)

        case .ask(let text):
            model.query = ""
            model.assistant?.ask(text)

        case .searchWeb(let text):
            model.query = ""
            model.assistant?.askWeb(text)

        case .command(let text, let target):
            model.query = ""
            model.assistant?.command(text, selected: target)

        case .pick(let id):
            model.assistant?.pick(id)

        case .followUp(let follow):
            model.query = ""
            model.assistant?.followUp(follow)

        case .open(let id):
            // 여기서는 사용자가 "그 메모를 보자" 고 한 것이다. 앞으로 데려온다.
            model.assistant?.reset()
            model.clear()
            close(returningFocus: false)
            windows.reveal(id)

        case .nothing:
            // 길을 찾는 중의 빈 ⌘⏎ 는 기다리라는 뜻으로 둔다 — 닫으면 찾던 것을 버린다.
            if model.planner?.isBusy == true { return }
            close()
        }
    }

    /// 적기가 끝났다 — 상자를 비우고, 권할 것(시각·가는 길)이 있으면 결과 카드를 세운 채 다음 글을 받고, 없으면 닫는다.
    ///
    /// 적고 하던 일로 돌아간다. 메모 창은 바탕화면 높이에 있어서 여기서 활성화하면 **보이지 않는 창으로
    /// 키보드가 넘어가고** 이어서 친 글자가 사라진다. 카드가 선 상자도 다음 글을 받는다 — 되묻지 않는다.
    private func left(_ memo: Memo) {
        model.assistant?.reset()   // 남아 있던 웹의 답은 여기서 물러난다 — 새 메모로 끝났다.
        model.clear()
        if !model.show(left: memo, hint: FirstNote.takeHint()) { close() }
        announce(memo)
    }

    /// ⌥⌘⏎ / ✦ — 비서에게. 기본 ⌘⏎ 가 적기로 돌아간 뒤로 비서는 이 길로만 (`QuickCaptureModel.commitAsk`).
    private func ask() {
        switch model.commitAsk() {
        case .ask(let text):
            model.query = ""
            model.assistant?.ask(text)
        case .searchWeb(let text):
            model.query = ""
            model.assistant?.askWeb(text)
        case .command(let text, let target):
            model.query = ""
            model.assistant?.command(text, selected: target)
        case .followUp(let follow):
            model.query = ""
            model.assistant?.followUp(follow)
        default:
            break
        }
    }

    /// 적은 것이 어디에 놓였는지 **그 물건이 직접 나와서** 말한다.
    ///
    /// 확인을 이렇게 주는 이유는 §8 에 이미 적혀 있다 — 활성화해 버리면
    /// 보이지 않는 창으로 입력이 넘어가고, 아무 표시도 안 하면 "적히긴
    /// 한 건가" 가 남는다. 잠깐 보였다 내려앉는 것이 둘 다 피하는 길이다.
    ///
    /// 달라진 것은 **나오는 물건이 둘이라는 것**이다. 날짜가 없으면 종이가,
    /// 날짜가 있으면 달력이 나온다 (§7.2). 일정을 적었는데 종이가 나오면
    /// 그것은 거짓말이다 — 그 메모는 종이로 남지 않기 때문이다.
    private func announce(_ memo: Memo) {
        guard let day = Schedule(memo).day() else {
            windows.announce(memo)
            return
        }
        onScheduled(day)
    }
}

/// 빠른 입력의 SwiftUI 계층을 담는 뷰.
///
/// 하는 일은 하나 — **다시 그려진 높이를 창에 알린다.**
///
/// 예전에는 모델이 "이제 커졌을 것" 이라고 짐작해 창 크기를 다시 잡았다.
/// 짐작에서 빠진 변화가 하나라도 있으면 창이 내용보다 작은 채로 남는데,
/// 날짜 칩이 정확히 그랬다: 칩은 곧바로 떴지만 창은 검색이 끝나는 120ms
/// 뒤에야 따라와, 그동안 상자가 내용에 밀려 위로 삐져나오고 윗줄이 잘렸다.
///
/// 짐작을 걷어내고 **실제로 잰 높이**만 쓴다. 여기서 알리는 것은 SwiftUI 가
/// 배치를 끝낸 직후라, 창은 같은 화면 갱신 안에서 크기를 맞춘다.
final class CaptureHostingView: NSHostingView<QuickCaptureView> {
    var onContentHeightChange: (CGFloat) -> Void = { _ in }

    private var reportedHeight: CGFloat = 0
    /// 알림 → 창 크기 변경 → 다시 배치 → 알림 … 으로 돌지 않게 잠근다.
    private var isReporting = false

    override func layout() {
        super.layout()
        guard !isReporting else { return }

        let height = fittingSize.height
        // 0.5pt 미만은 반올림 잡음이다. 그것까지 쫓으면 창이 떨린다.
        guard abs(height - reportedHeight) > 0.5 else { return }
        reportedHeight = height

        isReporting = true
        onContentHeightChange(height)
        isReporting = false
    }
}

/// 첫 메모 뒤의 한 줄 — 다섯 장 안내 대신 **실제 자기 메모**부터 (인계서 묶음 3 `#first-real-note`).
///
/// 처음 켠 사람은 안내서를 읽는 대신 상자에 한 줄 적고, 적힌 뒤에 필요한 조작 하나만 듣는다: 다시 부르는
/// 단축키. 나머지는 메뉴의 「시작하기 및 사용 안내…」에 그대로 있다. 한 번 보이면 다시 없다 — 이 기기의 일이다.
enum FirstNote {
    private static let key = "capture.first-note-hinted"

    /// 아직 안 보였으면 한 줄을 주고 보였다고 적는다. 검증 주행(`LAZYMEMO_*` 환경)에서는 없다 — 첫 실행 창을 안 띄우는
    /// 것과 같은 규칙(`AppDelegate`)이고, 임시 Vault 로 도는 스크립트가 개발 기계의 표를 먹어 버리지 않게.
    static func takeHint(
        defaults: UserDefaults = .standard, shortcut: String = "⌥⌘N",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        guard !environment.keys.contains(where: { $0.hasPrefix("LAZYMEMO_") }) else { return nil }
        guard !defaults.bool(forKey: key) else { return nil }
        defaults.set(true, forKey: key)
        return L("종이가 바탕화면에 섰어요 · 다시 적을 땐 \(shortcut) · 나머지는 메뉴바 아이콘 → 시작하기 및 사용 안내")
    }

    /// 시험·검증용 — 다시 보이게.
    static func reset(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
}
