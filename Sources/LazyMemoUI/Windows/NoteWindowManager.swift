import AppKit
import LazyMemoCore
import Observation

/// 메모 목록과 바탕화면 창을 맞춰 두는 곳 (D2, 설계문서 §7).
///
/// 규칙 하나: **메모는 기본적으로 바탕화면에 있다.** 사용자가 창을 닫으면
/// `layout.json` 에 숨김으로 기록되고, 그때만 사라진다. 닫기는 삭제가 아니다.
@MainActor
final class NoteWindowManager {
    /// 한 번에 띄우는 창의 상한. 메모가 수백 장일 때 화면과 메모리를
    /// 동시에 날려먹지 않기 위한 안전장치다 (성능 예산 §11).
    /// 넘치는 메모는 메뉴바 목록에서 열 수 있다.
    static let maximumVisibleWindows = 24

    private var controllers: [ULID: NoteWindowController] = [:]
    private let store: MemoStore
    private let layouts: LayoutStore
    private let previews: LinkPreviewStore

    init(store: MemoStore, layouts: LayoutStore, previews: LinkPreviewStore) {
        self.store = store
        self.layouts = layouts
        self.previews = previews
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
        }

        layouts.prune(keeping: Set(store.memos.map(\.id)))
    }

    /// 숨기지 않은 메모 중 상한만큼. 목록은 이미 고정·최근순으로 정렬돼 있다.
    private func plannedVisibleMemos() -> [Memo] {
        store.memos
            .filter { layouts.layout(for: $0.id)?.hidden != true }
            .prefix(Self.maximumVisibleWindows)
            .map { $0 }
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
            frame: frame,
            onFrameChange: { [weak self] id, frame in
                self?.recordFrame(frame, for: id)
            },
            onCloseRequest: { [weak self] id in
                self?.hide(id)
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
