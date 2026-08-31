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

    /// 규칙과 상관없이 **지금 나와 있어야 하는** 종이.
    ///
    /// §7.2 는 "날짜가 붙은 것은 달력이 맡는다, 그 날이 오면 달력이 꺼내 준다"
    /// 고 약속했는데, 꺼내 주는 쪽이 없었다 — 적힌 시각이 와도 아무 일도 일어나지
    /// 않았다. 여기가 그 자리다 (`DueClock`).
    ///
    /// **`layout.json` 에 적지 않는다.** 적는 순간 그것은 「사람이 꺼내 둔 것」이
    /// 되어(§7.2 의 예외) 그 메모는 영영 바탕화면에 남는다. 시각이 되어 잠깐
    /// 나온 것과 사람이 꺼내 둔 것은 다른 일이다.
    private var surfaced: Set<ULID> = []
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
            // **되돌리는 줄을 든 종이는 남는다** (D6). 지운 그 자리에서
            // 되살릴 수 있어야 하므로, 줄이 스스로 물러날 때까지 창을 거두지
            // 않는다 — 그때 `onDeletionSettled` 가 여기를 다시 부른다.
            if controller.isMourning { continue }
            controllers.removeValue(forKey: id)
            Task { await controller.teardown() }
        }

        for memo in visible {
            if let existing = controllers[memo.id] {
                existing.adopt(memo)
            } else {
                // 시각이 되어 꺼낸 종이는 여기서도 기록하지 않는다 — 한 번만
                // 안 적는 것으로는 부족하고, 다시 지어질 때마다 안 적어야 한다.
                open(memo, activating: false, recording: !surfaced.contains(memo.id))
            }
            // 달력에서 내려온 종이는 **나왔다는 것을 스스로 말한다.** 바탕화면
            // 레벨의 창은 브라우저 뒤에 나므로, 그냥 두면 「종이로」를 누른
            // 사람에게는 아무 일도 일어나지 않은 것으로 보인다 (§7.1 의 셋째 규칙).
            if returned.contains(memo.id) { controllers[memo.id]?.announce() }
        }

        // **휴지통에 있는 것의 자리도 남긴다.** 되돌리면 있던 자리로 돌아와야
        // 하는데, 지우는 순간 자리를 지워 버리면 되살린 종이가 엉뚱한 곳에 뜬다.
        layouts.prune(keeping: Set(store.memos.map(\.id)).union(store.trash.map(\.id)))
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
    ///
    /// **시각이 되어 꺼낸 종이가 먼저다.** 상한(24장)에 밀려 잘리면, 지금 이 앱이
    /// 사용자에게 하려는 말이 통째로 사라진다.
    private func plannedVisibleMemos() -> [Memo] {
        // 치워 둔 것은 규칙이 뭐라 하든 서지 않는다 (`Tidy`). 다만 시각이
        // 되어 꺼낸 종이는 예외다 — 그것은 앱이 지금 하려는 말이다.
        let wanted = store.memos.filter {
            ($0.tidied == nil && staysOnDesktop($0)) || surfaced.contains($0.id)
        }
        let risen = wanted.filter { surfaced.contains($0.id) }
        let rest = wanted.filter { !surfaced.contains($0.id) }
        return Array((risen + rest).prefix(Self.maximumVisibleWindows))
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

    /// - Parameter recording: `layout.json` 에 "이 메모는 바탕화면에 있다" 를
    ///   적을지. 시각이 되어 잠깐 꺼낸 종이는 적지 않는다 (`surfaced`).
    @discardableResult
    func open(_ memo: Memo, activating: Bool, recording: Bool = true) -> NoteWindowController {
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
        // 되돌리는 줄이 스스로 물러나면 그때 창을 거둔다 (`NoteModel`).
        controller.model.onDeletionSettled = { [weak self] in self?.sync() }
        controllers[memo.id] = controller
        recordFrame(frame, for: memo.id)
        if recording { layouts.setHidden(false, for: memo.id) }
        controller.show(activating: activating)
        return controller
    }

    /// 규칙과 상관없이 이 종이를 지금 꺼내 놓는다 (`DueClock`).
    ///
    /// **잠깐 보였다 내려앉는 것으로는 부족하다.** 시각이 되었을 때 자리를 비운
    /// 사람이 이 앱에서 가장 자주 겪는 실패("적었는데 그냥 지나갔다")의 당사자
    /// 이므로, 종이는 나와서 **그대로 있는다.** 돌아온 사람이 화면에서 그것을
    /// 본다. 하루가 끝나면 스스로 물러난다 (`clearSurfaced`).
    func surface(_ id: ULID) {
        guard let memo = store.memo(id), controllers[id] == nil else { return }
        surfaced.insert(id)
        open(memo, activating: false, recording: false).announce()
    }

    /// 꺼내 놓았던 종이를 도로 달력에 맡긴다 — 하루가 끝날 때 (`DayClock`).
    ///
    /// 사람이 그대로 두었다고 해서 그 자리가 사람의 뜻이 되지는 않는다.
    /// 어제의 일정이 오늘도 바탕화면에 서 있으면 그것부터가 낡은 종이다 (철학 3).
    func clearSurfaced() {
        let risen = surfaced
        surfaced.removeAll()
        for id in risen where !isVisibleByRule(id) {
            guard let controller = controllers.removeValue(forKey: id) else { continue }
            Task { await controller.teardown() }
        }
    }

    /// 꺼내 준 것과 상관없이, 규칙만으로도 이 종이가 바탕화면에 있는가.
    private func isVisibleByRule(_ id: ULID) -> Bool {
        guard let memo = store.memo(id) else { return false }
        return staysOnDesktop(memo)
    }

    /// 방금 적힌 메모를 바탕화면에 내려놓는다.
    ///
    /// **포커스를 뺏지 않는다.** 빠른 입력으로 한 줄 적은 사람은 하던 일로
    /// 돌아가는 중이지, 새 창을 받으러 온 것이 아니다. 대신 종이가 잠깐
    /// 앞으로 나왔다 내려앉아 "적혔다" 를 눈으로 알려준다.
    func announce(_ memo: Memo) {
        open(memo, activating: false).announce()
    }

    /// 메모를 앞으로 데려와 커서를 세운다.
    ///
    /// - Parameter keepingPlace: 이 메모의 **자리**를 그대로 둘지.
    ///
    ///   달력에서 일정을 누르는 것은 「보는 일」이지 「꺼내 두는 일」이 아니다.
    ///   그런데 여는 길이 하나뿐이라 읽으려는 클릭이 `layout.json` 에
    ///   `hidden = false` 를 적었고, 그러면 §7.2 의 예외("사람이 정한 것이
    ///   이긴다")에 걸려 그 일정은 **날짜를 가진 채 영영 바탕화면에 남았다.**
    ///   보려고 한 번 누른 것이 자리를 영구히 옮기는 조작이 된 셈이다.
    ///
    ///   메뉴 목록과 빠른 입력은 그대로 기록한다 — 그 두 목록은 찬 점·빈 점으로
    ///   "바탕화면에 있음/치워 둠" 을 말하고 있으므로(§14.10), 거기서 줄을 누르는
    ///   것은 그 낱말대로 **꺼내는** 일이 맞다.
    func reveal(_ id: ULID, activating: Bool = true, keepingPlace: Bool = false) {
        guard let memo = store.memo(id) else { return }
        // 치워 둔 것을 찾아서 연 것은 **도로 꺼낸다는 뜻**이다. 그대로 두면
        // 창은 떠 있는데 목록에는 없는 메모가 되고, 다음 날 규칙이 그 창을
        // 도로 걷어 간다 — 사람이 방금 꺼낸 것을.
        if memo.tidied != nil {
            Task { await store.untidy(id) }
        }
        if keepingPlace {
            surfaced.insert(id)
        } else {
            layouts.setHidden(false, for: id)
        }
        open(memo, activating: activating, recording: !keepingPlace).focusEditor()
    }

    /// 창을 치운다. 메모는 그대로 남는다 (D6 과는 별개의 개념이다).
    func hide(_ id: ULID) {
        guard let controller = controllers.removeValue(forKey: id) else { return }
        // 사람이 치웠으면 꺼내 놓은 것도 끝난 일이다 — 안 지우면 다음 `sync`
        // 가 규칙을 무시하고 도로 띄운다.
        surfaced.remove(id)
        layouts.setHidden(true, for: id)
        Task { await controller.teardown() }
    }

    func isVisible(_ id: ULID) -> Bool {
        controllers[id] != nil
    }

    /// 하루가 바뀌었다 (`DayClock`) — 종이마다 나이를 다시 재게 한다.
    ///
    /// 철학 3("오래된 것은 스스로 물러난다")은 하루가 지나야 발화하는데,
    /// 창은 메모가 바뀌지 않는 한 다시 그려지지 않는다. 알려 주지 않으면
    /// 어제 적은 종이가 몇 주째 갓 적은 것처럼 또렷하게 서 있다.
    func dayChanged(now: Date = Date()) {
        for controller in controllers.values {
            controller.model.dayChanged(now: now)
        }
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

    /// 자리만 적는다. **「나와 있다/치웠다」는 건드리지 않는다.**
    ///
    /// 적힌 뜻이 없으면 규칙이 말하는 자리를 그대로 적는다 — 예전에는 무조건
    /// `hidden = false` 로 떨어져서, 잠깐 꺼내 보인 종이가 그 사실만으로
    /// 「사람이 꺼내 둔 것」이 되어 영영 바탕화면에 남았다 (§7.2 의 예외).
    private func recordFrame(_ frame: CGRect, for id: ULID) {
        let hidden = layouts.layout(for: id)?.hidden
            ?? (store.memo(id)?.isScheduled ?? false)
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
