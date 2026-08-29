import AppKit
import LazyMemoCore
import Observation

/// 메모 목록과 바탕화면 창을 맞춰 두는 곳 (D2, 설계문서 §7).
///
/// 규칙 하나: **날짜 없는 메모는 바탕화면에 있고, 날짜 붙은 것은 달력이 맡는다**
/// (§7.2). 사용자가 창을 닫으면 `layout.json` 에 숨김으로 기록되고, 그때만
/// 사라진다. 닫기는 삭제가 아니다.
@MainActor
final class NoteWindowManager {
    /// 한 번에 띄우는 창의 상한. 메모가 수백 장일 때 화면과 메모리를
    /// 동시에 날려먹지 않기 위한 안전장치다 (성능 예산 §11).
    /// 넘치는 메모는 메뉴바 목록에서 열 수 있다.
    static let maximumVisibleWindows = 24

    private var controllers: [ULID: NoteWindowController] = [:]
    /// 지난번에 본 각 메모의 자리 — 일정이었는가 아닌가.
    /// 자리가 바뀐 것을 알아채는 유일한 근거다 (`handover`).
    private var wasScheduled: [ULID: Bool] = [:]

    /// 종이에서 달력으로 건너가려 할 때 부르는 통로. 창 관리자는 달력 창을
    /// 알지 못하므로 바깥(`MenuBarController`)이 이어 준다.
    var onCalendarRequest: (ULID) -> Void = { _ in }

    private let store: MemoStore
    private let layouts: LayoutStore
    private let previews: LinkPreviewStore
    private let appearance: PaperAppearance

    init(
        store: MemoStore, layouts: LayoutStore, previews: LinkPreviewStore,
        appearance: PaperAppearance
    ) {
        self.store = store
        self.layouts = layouts
        self.previews = previews
        self.appearance = appearance
    }

    // MARK: 동기화

    func start() {
        sync()
        observeStore()
    }

    /// `@Observable` 변화를 좇는다. 한 번 발화하면 재구독해야 한다.
    private func observeStore() {
        withObservationTracking {
            _ = store.memos
        } onChange: {
            Task { @MainActor [weak self] in
                self?.sync()
                self?.observeStore()
            }
        }
    }

    func sync() {
        let returned = applyHandovers()
        let visible = plannedVisibleMemos()
        let wanted = Set(visible.map(\.id))

        for (id, controller) in controllers where !wanted.contains(id) {
            controllers.removeValue(forKey: id)
            Task { await controller.teardown() }
        }

        for memo in visible {
            if let existing = controllers[memo.id] {
                existing.adopt(memo)
            } else {
                open(memo, activating: false)
            }
            // 달력에서 내려온 종이는 **나왔다는 것을 스스로 말한다.** 바탕화면
            // 레벨의 창은 브라우저 뒤에 나므로, 그냥 두면 「종이로」를 누른
            // 사람에게는 아무 일도 일어나지 않은 것으로 보인다 (§7.1 의 셋째 규칙).
            if returned.contains(memo.id) { controllers[memo.id]?.announce() }
        }

        layouts.prune(keeping: Set(store.memos.map(\.id)))
    }

    /// **자리가 바뀐 메모를 따라 종이를 옮긴다** (설계문서 §7.2).
    ///
    /// §7.2 는 메모가 태어나는 순간에만 적용되고 있었다. 날짜를 나중에 붙이거나
    /// 떼는 길이 어디에도 없었고, 있었다 해도 `layout.json` 의 기록이 규칙을
    /// 이기므로(사람이 정한 것이 이긴다) 한 번 종이가 된 메모는 일정이 되어도
    /// 종이로 남았다 — 자리를 나눠 놓고 **옮길 수 없게** 해 둔 셈이다.
    ///
    /// 그래서 자리가 바뀌는 순간에만 그 기록을 다시 쓴다. 달력의 「종이로」,
    /// 종이의 「달력에 놓기」, 그리고 MCP 로 Claude 가 날짜를 붙이는 것까지
    /// 전부 이 한 곳을 지난다 — 세 길에 각각 적으면 하나는 반드시 어긋난다.
    /// - Returns: 달력에서 종이로 **내려온** 메모들. 나왔다는 것을 보여줘야 한다.
    private func applyHandovers() -> Set<ULID> {
        var next: [ULID: Bool] = [:]
        var returned: Set<ULID> = []
        for memo in store.memos {
            let now = memo.isScheduled
            if let hidden = Self.handover(was: wasScheduled[memo.id], now: now) {
                layouts.setHidden(hidden, for: memo.id)
                if !hidden { returned.insert(memo.id) }
            }
            next[memo.id] = now
        }
        wasScheduled = next
        return returned
    }

    /// 자리가 바뀌었을 때 `layout.json` 에 새로 적을 `hidden` 값. 없으면 `nil`.
    ///
    /// 날짜를 얻으면 달력이 맡으므로 종이는 물러나고(`hidden = true`), 날짜를
    /// 떼면 다시 눈에 밟혀야 하므로 돌아온다(`hidden = false`). 처음 본 메모는
    /// 바뀐 것이 아니다 — 기동 직후 모든 일정이 한꺼번에 숨김으로 기록되면
    /// 사람이 꺼내 둔 일정(§7.2 의 예외)이 통째로 사라진다.
    nonisolated static func handover(was: Bool?, now: Bool) -> Bool? {
        guard let was, was != now else { return nil }
        return now
    }

    /// 종이로 있어야 할 메모 중 상한만큼. 목록은 이미 고정·최근순으로 정렬돼 있다.
    private func plannedVisibleMemos() -> [Memo] {
        store.memos
            .filter { staysOnDesktop($0) }
            .prefix(Self.maximumVisibleWindows)
            .map { $0 }
    }

    private func staysOnDesktop(_ memo: Memo) -> Bool {
        Self.staysOnDesktop(isScheduled: memo.isScheduled, layout: layouts.layout(for: memo.id))
    }

    /// 이 메모가 바탕화면에 종이로 내려앉는가 (설계문서 §7.2).
    ///
    /// **날짜가 붙은 것은 달력이 맡는다.** 언제 볼지 이미 정해진 일을 지금
    /// 눈앞에 쌓아 둘 이유가 없다 — 그 날이 오면 달력이 꺼내 준다(§14.2 —
    /// 시간이 유일한 구조). 종이가 되는 것은 **언제 볼지 아직 정해지지 않은
    /// 것**뿐이고, 그런 것이야말로 눈에 밟혀야 잊히지 않는다.
    ///
    /// 이 갈림길을 여기 한 곳에 두는 이유: 메모가 태어나는 길이 셋이다
    /// (달력의 「이 날에 적기」, 빠른 입력, MCP). 만드는 자리마다 "종이를
    /// 낼까 말까" 를 적으면 셋 중 하나가 반드시 어긋나고, 실제로 어긋나
    /// 있었다 — 달력에서 일정을 적었는데 바탕화면에 종이가 한 장 생겼다.
    ///
    /// **사람이 한 번 정한 것은 언제나 이긴다.** `layout.json` 에 기록이
    /// 있다는 것은 그 메모를 연 적이 있거나 치운 적이 있다는 뜻이므로, 이
    /// 규칙은 아무도 정한 적 없는 메모에만 말한다.
    nonisolated static func staysOnDesktop(isScheduled: Bool, layout: WindowLayout?) -> Bool {
        if let layout { return !layout.hidden }
        return !isScheduled
    }

    // MARK: 창 열고 닫기

    @discardableResult
    func open(_ memo: Memo, activating: Bool) -> NoteWindowController {
        if let existing = controllers[memo.id] {
            existing.adopt(memo)
            existing.show(activating: activating)
            return existing
        }

        let frame = resolveFrame(for: memo)
        let controller = NoteWindowController(
            memo: memo,
            store: store,
            previews: previews,
            appearance: appearance,
            frame: frame,
            onFrameChange: { [weak self] id, frame in
                self?.recordFrame(frame, for: id)
            },
            onCloseRequest: { [weak self] id in
                self?.hide(id)
            },
            onCalendarRequest: { [weak self] id in
                self?.onCalendarRequest(id)
            }
        )
        controllers[memo.id] = controller
        recordFrame(frame, for: memo.id)
        layouts.setHidden(false, for: memo.id)
        controller.show(activating: activating)
        return controller
    }

    /// 방금 적힌 메모를 바탕화면에 내려놓는다.
    ///
    /// **포커스를 뺏지 않는다.** 빠른 입력으로 한 줄 적은 사람은 하던 일로
    /// 돌아가는 중이지, 새 창을 받으러 온 것이 아니다. 대신 종이가 잠깐
    /// 앞으로 나왔다 내려앉아 "적혔다" 를 눈으로 알려준다.
    func announce(_ memo: Memo) {
        open(memo, activating: false).announce()
    }

    func reveal(_ id: ULID, activating: Bool = true) {
        guard let memo = store.memo(id) else { return }
        layouts.setHidden(false, for: id)
        open(memo, activating: activating).focusEditor()
    }

    /// 창을 치운다. 메모는 그대로 남는다 (D6 과는 별개의 개념이다).
    func hide(_ id: ULID) {
        guard let controller = controllers.removeValue(forKey: id) else { return }
        layouts.setHidden(true, for: id)
        Task { await controller.teardown() }
    }

    func isVisible(_ id: ULID) -> Bool {
        controllers[id] != nil
    }

    /// 종료 직전 — 저장 버튼이 없으므로 여기서 전부 확정한다.
    func flushAll() async {
        for controller in controllers.values {
            await controller.teardown()
        }
        controllers.removeAll()
        layouts.flush()
    }

    // MARK: 좌표

    private func recordFrame(_ frame: CGRect, for id: ULID) {
        let hidden = layouts.layout(for: id)?.hidden ?? false
        layouts.set(
            WindowLayout(frame: frame, displayUUID: Self.displayUUID(for: frame), hidden: hidden),
            for: id
        )
    }

    /// 저장된 좌표가 있으면 쓰고, 화면이 사라졌으면 주 화면으로 데려온다 (§7).
    private func resolveFrame(for memo: Memo) -> CGRect {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        guard let saved = layouts.layout(for: memo.id) else {
            return cascadedFrame(on: fallback)
        }
        return FrameClamping.restore(saved.frame, onto: screens, fallback: fallback)
    }

    /// 새 메모 자리. 우상단에서 시작해 계단식으로 내려온다.
    private func cascadedFrame(on screen: CGRect) -> CGRect {
        let size = CGSize(width: 260, height: 200)
        let step: CGFloat = 30
        let occupied = controllers.values.map(\.frame)

        for index in 0..<40 {
            let origin = CGPoint(
                x: screen.maxX - size.width - 40 - CGFloat(index) * step,
                y: screen.maxY - size.height - 40 - CGFloat(index) * step
            )
            let candidate = CGRect(origin: origin, size: size)
            guard screen.contains(candidate) else { break }
            if !occupied.contains(where: { $0.origin.equalTo(origin) }) {
                return candidate
            }
        }

        // 계단이 화면을 벗어나면 처음 자리로 되돌아간다 — 겹치더라도
        // 화면 밖에 창을 만드는 것보다 낫다.
        return CGRect(
            x: screen.maxX - size.width - 40,
            y: screen.maxY - size.height - 40,
            width: size.width, height: size.height
        )
    }

    /// 디스플레이 UUID. 모니터를 바꿔 꽂아도 같은 화면을 알아보게 한다.
    private static func displayUUID(for frame: CGRect) -> String? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }),
              let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber
        else { return nil }

        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
