import AppKit
import LazyMemoCore
import SwiftUI

/// 메모 한 장에 대응하는 창 (D2).
@MainActor
final class NoteWindowController: NSObject, NSWindowDelegate {
    let id: ULID
    let model: NoteModel

    private let window: DesktopLevelWindow
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
    /// 가는 길 카드 한 장의 몫 — 머리·큰 줄·띠·탈것 두 줄·하차·꼬리.
    static let routeCardHeight: CGFloat = 280

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
        window.setFrame(frame, display: true, animate: true)
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
        window.cancelSettling()
        window.delegate = nil
        window.orderOut(nil)
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
        onFrameChange(id, window.frame)
    }
}
