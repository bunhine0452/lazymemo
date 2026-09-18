import AppKit
import LazyMemoCore
import SwiftUI

/// 메모 한 장에 대응하는 창 (D2).
@MainActor
final class NoteWindowController: NSObject, NSWindowDelegate {
    let id: ULID
    let model: NoteModel

    /// 시험이 키를 보내려고 본다 — 그 밖에는 이 컨트롤러만 만진다.
    let window: DesktopLevelWindow
    private let onFrameChange: (ULID, CGRect) -> Void
    private let onCloseRequest: (ULID) -> Void
    /// 서랍으로 날아가는 중. **이때의 좌표는 적지 않는다** — 서랍만 한 크기로
    /// 줄어드는 그 프레임들이 `layout.json` 에 들어가면, 꺼냈을 때 종이가
    /// 서랍 자리에 손톱만 하게 돌아온다.
    private var isFlying = false
    /// 자리 카드 때문에 종이를 늘린 적이 있는가 — 한 번뿐이다. 그 뒤로 줄이는 것은 사람의 몫.
    private var grewForPlaces = false
    private var grewForRoute = false
    /// 기본 종이의 키. 카드가 서면 여기에 더한다.
    static let defaultPaper: CGFloat = 200
    /// 기본 종이의 폭 (`NoteWindowManager.cascadedFrame`).
    static let defaultWidth: CGFloat = 260
    /// 가는 길 카드 한 장의 몫 — 머리·큰 줄·띠·탈것 두 줄·하차·꼬리.
    static let routeCardHeight: CGFloat = 280

    // MARK: 글에 맞춰 자라기 (`PaperFit`)

    /// 사람이 손으로 크기를 정한 종이인가. 그렇다면 앱은 **크게 넘칠 때만** 자라고
    /// 결코 줄이지 않는다 — 접어 둔 것은 그러라고 접은 것이다.
    private var userSized: Bool
    /// 언제까지가 **우리가** 크기를 바꾸는 중인가. 그 사이에 오는 `windowDidResize` 는
    /// 사람의 손이 아니다. 시각으로 두는 이유: 애니메이션의 마지막 알림은 완료 핸들러
    /// **뒤에** 한 번 더 오기도 해서, 깃발을 그때 내리면 앱이 늘린 것이 「사람이 정한
    /// 크기」로 둔갑한다 — 그 뒤로 종이는 두 번 다시 글에 맞추지 않는다.
    private var selfResizeUntil = Date.distantPast
    private var isResizingSelf: Bool { Date() < selfResizeUntil }
    /// 치는 동안에는 기다린다 — 키를 누를 때마다 창이 움직이면 글을 쓸 수가 없다.
    private var fitTask: Task<Void, Never>?
    /// 지난번에 들은 글 높이. 한 번에 크게 뛰면 붙여넣기다.
    private var lastTextHeight: CGFloat = 0
    /// 폭을 넓힌 뒤 한 번은 다시 잰다 — 접힘이 풀린 실제 높이는 다시 깔아 봐야 안다.
    private var wantsRemeasure = false

    /// 지도가 앉은 종이의 키. 기본 종이(200pt)에 카드(~110pt)가 서면 글이 두 줄만 남는다 —
    /// 사진과 달리 지도는 몫을 나눠 줄일 수 없어(작으면 지도가 아니다) 종이가 자란다.
    static let paperWithMap: CGFloat = 320

    init(
        memo: Memo,
        store: MemoStore,
        previews: LinkPreviewStore,
        appearance: PaperAppearance,
        claude: ClaudeRunner? = nil,
        frame: CGRect,
        onFrameChange: @escaping (ULID, CGRect) -> Void,
        onCloseRequest: @escaping (ULID) -> Void,
        onCalendarRequest: @escaping (ULID) -> Void = { _ in }
    ) {
        self.id = memo.id
        self.model = NoteModel(memo: memo, store: store, previews: previews, claude: claude)
        self.window = DesktopLevelWindow(contentRect: frame)
        self.onFrameChange = onFrameChange
        self.onCloseRequest = onCloseRequest
        // 앱이 내놓는 크기가 아니면 사람이 정했거나 앱이 이미 글에 맞춰 늘린 것이다 —
        // 어느 쪽이든 줄이면 안 된다 (`PaperFit.looksAppSized`).
        self.userSized = !PaperFit.looksAppSized(frame.size, defaults: Self.appSizes)
        super.init()

        // 겹쳐 뜨는 조작 버튼도 첫 클릭에 눌려야 한다 (`FirstMouseHostingView`).
        let hosting = FirstMouseHostingView(rootView: NoteView(
            model: model,
            onClose: { [id] in onCloseRequest(id) },
            onCalendar: { [id] in onCalendarRequest(id) },
            appearance: appearance
        ))
        hosting.rootView.onPlacesAppear = { [weak self] in self?.growForPlaces() }
        hosting.rootView.onRouteAppear = { [weak self] in self?.growForRoute() }
        // 글이 얼마나 자리를 먹는지 들린다 — 종이가 그에 맞춰 한 번 자란다 (`PaperFit`).
        hosting.rootView.onTextHeight = { [weak self] height in self?.textHeightChanged(height) }
        // Esc 는 어디서 눌리든 한곳으로 — 본문에서(텍스트 뷰), 손잡이만 잡은 채로(창).
        hosting.rootView.onEscape = { [weak self] in self?.escape() }
        window.onEscape = { [weak self] in self?.escape() }
        // 창 크기는 layout.json 이 정본이다. 뷰가 끌고 가게 두지 않는다.
        hosting.sizingOptions = []

        window.contentView = hosting
        window.setFrame(frame, display: false)
        window.delegate = self
    }

    var frame: CGRect { window.frame }

    /// 지웠지만 아직 되돌릴 수 있는 종이 (D6). 이 동안에는 창을 거두지 않는다.
    var isMourning: Bool { model.justDeleted != nil }

    func show(activating: Bool = false) {
        window.orderFront(nil)
        if activating {
            NSApp.activate()
            window.makeKey()
        }
    }

    func hide() {
        window.cancelSettling()
        window.orderOut(nil)
    }

    /// 방금 적힌 메모 — 포커스를 뺏지 않고 잠깐 보였다 내려앉는다.
    func announce() {
        show(activating: false)
        window.riseBriefly()
    }

    /// 파일이 밖에서 바뀌었을 때 창 내용을 맞춘다.
    func adopt(_ memo: Memo) {
        model.adopt(memo)
    }

    /// 자리 카드가 서면 종이를 아래로 늘린다 — 윗변은 그대로, 사람이 둔 자리가 안 흔들린다.
    private func growForPlaces() {
        guard !grewForPlaces else { return }
        grewForPlaces = true
        grow(toAtLeast: Self.paperWithMap + (grewForRoute ? Self.routeCardHeight : 0))
    }

    /// 가는 길 카드가 서면 그만큼 더 — 카드는 줄이 여럿이라 접을 수 없다.
    private func growForRoute() {
        guard !grewForRoute else { return }
        grewForRoute = true
        grow(toAtLeast: (grewForPlaces ? Self.paperWithMap : Self.defaultPaper) + Self.routeCardHeight)
    }

    private func grow(toAtLeast height: CGFloat) {
        guard !isFlying else { return }
        var frame = window.frame
        guard frame.height < height else { return }
        let delta = height - frame.height
        frame.origin.y -= delta
        frame.size.height = height
        if let screen = window.screen?.visibleFrame, frame.minY < screen.minY {
            frame.origin.y = screen.minY
        }
        // 카드가 늘린 것도 **앱이 정한 크기**다 — 이 사이에 오는 리사이즈 알림을
        // 사람의 손으로 세면, 종이는 열리자마자 「사람이 정한 크기」가 되어 버린다.
        selfResizeUntil = Date().addingTimeInterval(1)
        window.setFrame(frame, display: true, animate: true)
        selfResizeUntil = Date().addingTimeInterval(0.2)
    }

    // MARK: 글에 맞춰 자라기

    /// 앱이 스스로 내놓는 종이 크기들. 이 중 하나가 아니면 사람의 손이 닿은 것이다.
    private static var appSizes: [CGSize] {
        [defaultPaper, paperWithMap, defaultPaper + routeCardHeight, paperWithMap + routeCardHeight]
            .map { CGSize(width: defaultWidth, height: $0) }
    }

    /// 글 높이가 바뀌었다 (`MemoTextEditor` 가 재서 알린다).
    ///
    /// **키를 누를 때마다 창을 움직이지 않는다.** 한 줄 칠 때마다 종이가 자라면
    /// 글자가 손끝에서 달아난다 — 손이 멈춘 뒤에 한 번 맞춘다. 다만 한꺼번에
    /// 크게 뛴 것은 붙여넣기나 다듬기 결과이므로 거의 곧바로 맞춘다.
    private func textHeightChanged(_ height: CGFloat) {
        let jump = height - lastTextHeight
        lastTextHeight = height
        guard height > 0 else { return }
        scheduleFit(after: jump > Paper.linePitch * 2 ? .milliseconds(60) : .milliseconds(450))
    }

    private func scheduleFit(after delay: Duration) {
        fitTask?.cancel()
        fitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.fitToContent()
        }
    }

    /// 지금 글에 맞는 크기로 한 번 자란다. 규칙은 `PaperFit` 에 있다.
    func fitToContent() {
        guard !isFlying, window.isVisible, let paper = measurePaper() else { return }
        let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let screen, let target = PaperFit.fit(paper, on: screen) else {
            wantsRemeasure = false
            return
        }

        // 폭이 바뀌면 글이 다시 접힌다 — 그 실제 높이는 다시 깔아 봐야 안다.
        wantsRemeasure = abs(target.width - paper.frame.width) > 1
        selfResizeUntil = Date().addingTimeInterval(Self.fitAnimation + 0.25)
        setFrameAnimated(target) { [weak self] in
            guard let self else { return }
            onFrameChange(id, window.frame)
            // 커서가 보이는 자리에 남아야 한다 — 붙여 넣은 글 끝이 화면 밖이면
            // 사람은 자기가 무엇을 붙였는지 못 본다.
            if let textView = window.contentView?.firstTextView {
                textView.scrollRangeToVisible(textView.selectedRange())
            }
            if wantsRemeasure {
                wantsRemeasure = false
                scheduleFit(after: .milliseconds(50))
            }
        }
    }

    /// 자라는 데 걸리는 시간. 눈이 따라갈 만큼만 — 길면 그 동안 글을 못 친다.
    static let fitAnimation: TimeInterval = 0.18

    /// 짧게, 그리고 **「동작 줄이기」를 켠 사람에게는 즉시.**
    private func setFrameAnimated(_ target: CGRect, completion: @escaping @MainActor () -> Void) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.setFrame(target, display: true)
            completion()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fitAnimation
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(target, display: true)
        } completionHandler: {
            MainActor.assumeIsolated { completion() }
        }
    }

    /// 지금 종이의 형편을 잰다. 글 높이는 텍스트 뷰의 배치에서, 카드·사진·꼬리의
    /// 몫은 **창 높이에서 글 칸을 뺀 나머지**로 — SwiftUI 쪽에 자를 대지 않아도 된다.
    private func measurePaper() -> PaperFit.Paper? {
        guard let textView = window.contentView?.firstTextView,
              let scrollView = textView.enclosingScrollView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              scrollView.frame.height > 1
        else { return nil }

        layoutManager.ensureLayout(for: container)
        let textHeight = layoutManager.usedRect(for: container).height
            + textView.textContainerInset.height * 2
        let chrome = max(0, window.frame.height - scrollView.frame.height)

        return PaperFit.Paper(
            frame: window.frame,
            textHeight: textHeight,
            chrome: chrome,
            paragraphs: model.text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 },
            lineHeight: Paper.linePitch,
            userSized: userSized
        )
    }

    // MARK: 서랍으로

    /// 끌고 있는 종이를 비쳐 보이게 한다.
    ///
    /// 서랍 위에 종이를 가져가면 **서랍이 종이 밑에 깔린다** — 끌고 있는 창이
    /// 앞에 서기 때문이다. 그대로 두면 사람은 자기가 무엇 위에 놓으려는지 볼
    /// 수 없고, 놓기 전에 확인할 수 없는 조작은 겨냥이 아니라 도박이다.
    func setDimmed(_ on: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            window.animator().alphaValue = on ? 0.5 : 1
        }
    }

    /// 서랍으로 날아 들어간다 — 줄어들면서 사라진다.
    ///
    /// 그냥 없어지면 「닫혔다」와 구별되지 않는다. 어디로 갔는지 눈이 따라가는
    /// 그 짧은 동안이 **종이를 잃지 않았다**는 유일한 증거다.
    func flyInto(_ target: CGRect, completion: @escaping @MainActor () -> Void) {
        window.cancelSettling()
        isFlying = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(target, display: true)
            window.animator().alphaValue = 0
        } completionHandler: {
            // 완료 핸들러는 메인에서 온다 — 격리를 그대로 잇는다.
            MainActor.assumeIsolated {
                // 창은 곧 거둬지지만, 되살아날 수도 있다 (되돌리기·다시 열기).
                // 투명한 채로 남겨 두면 다음에 열었을 때 보이지 않는 창이 뜬다.
                self.window.alphaValue = 1
                self.isFlying = false
                completion()
            }
        }
    }

    /// 창을 없애기 전에 반드시 부른다 — 저장 버튼이 없으므로 여기가 마지막 기회다.
    func teardown() async {
        await model.flush()
        fitTask?.cancel()
        window.cancelSettling()
        window.delegate = nil
        window.orderOut(nil)
    }

    /// Esc — 종이를 치운다. ×와 같은 길(서랍으로)이고 지우는 것이 아니다.
    ///
    /// 손이 키보드에 있을 때의 «닫기» 라, 종이가 사라진 뒤 **키보드를 원래 앱에
    /// 돌려주는 것**까지가 한 동작이다 — 상주 앱이 활성인 채 남으면 다음 타자가
    /// 허공으로 간다 (§7.1 다섯째 규칙). 방금 지운 종이는 되돌리는 줄이 서
    /// 있으니(D6) 건드리지 않는다 — 그 줄을 Esc 로 걷어 내면 되돌릴 자리가 없어진다.
    func escape() {
        guard !isMourning else { return }
        onCloseRequest(id)
        NSApplication.shared.deactivate()
    }

    func focusEditor() {
        show(activating: true)
        // 텍스트 뷰가 호스팅 뷰 아래 어딘가에 있다. 첫 responder 로 만들어
        // 단축키 한 번으로 바로 타자가 시작되게 한다 (§8).
        if let textView = window.contentView?.firstTextView {
            window.makeFirstResponder(textView)
        }
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard !isFlying else { return }
        onFrameChange(id, window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard !isFlying else { return }
        // **손으로 잡아 늘린 순간부터 이 종이는 사람의 것이다.** 그 뒤로 앱은
        // 줄이지 않고, 크게 넘칠 때만 자란다 (`PaperFit.handSlack`).
        if !isResizingSelf { userSized = true }
        onFrameChange(id, window.frame)
    }
}
