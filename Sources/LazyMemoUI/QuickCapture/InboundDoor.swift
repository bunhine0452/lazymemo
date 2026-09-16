import AppKit
import LazyMemoCore

/// 밖에서 들어오는 글이 지나는 **하나의 문.**
///
/// URL 스킴(`lazymemo://add`)·서비스 메뉴·클립보드 캡처가 전부 여기로 온다.
/// 문마다 따로 만들면 같은 글이 어디로 들어왔느냐에 따라 다르게 읽히고, 그것은
/// 「형식을 배우게 하지 않는다」를 문마다 다시 배우는 것이다 (`NoteReader`).
///
/// 안으로 들어온 뒤의 규칙도 하나다 — 날짜가 붙었으면 달력이 맡고, 아니면
/// 바탕화면에 종이가 나온다 (§7.2).
@MainActor
final class InboundDoor: NSObject {
    private let store: MemoStore
    private let windows: NoteWindowManager
    var onScheduled: (CalendarDate) -> Void = { _ in }
    /// 자리가 있는 약속이 밖에서 들어왔다 — 상자가 「어디서 출발하시나요?」를 세울 자리 (`RouteAsk`).
    var onRouteAsk: (Memo) -> Void = { _ in }

    init(store: MemoStore, windows: NoteWindowManager) {
        self.store = store
        self.windows = windows
    }

    @discardableResult
    func receive(_ inbound: InboundNote) async -> Memo? {
        let note = NoteReader.read(inbound)
        guard let memo = try? await store.create(
            body: note.body, due: note.due, at: note.at, every: note.every,
            place: note.place, geo: note.geo
        ) else { return nil }
        announce(memo)
        if RouteAsk.applies(memo) { onRouteAsk(memo) }
        return memo
    }

    @discardableResult
    func receive(text: String, place: String? = nil) async -> Memo? {
        guard let inbound = InboundNote.make(text: text, place: place) else { return nil }
        return await receive(inbound)
    }

    /// `lazymemo://add?text=…`. **받지 않는 것은 조용히 버린다** — 모르는 주소에
    /// 답을 하면 그 자체가 이 앱이 무엇을 받는지 알려 주는 신호가 된다.
    @discardableResult
    func receive(url: URL) async -> Memo? {
        guard let inbound = InboundLink.note(from: url) else { return nil }
        return await receive(inbound)
    }

    /// 서비스 메뉴 「lazymemo 에 적기」. 어느 앱에서든 글자를 골라 우클릭.
    ///
    /// AppKit 이 이 이름으로 부르므로 `Info.plist` 의 `NSMessage` 와 **글자 하나까지
    /// 같아야 한다.** 어긋나면 메뉴에는 나타나는데 눌러도 아무 일이 없다.
    @objc func addToLazyMemo(
        _ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string) else {
            error.pointee = L("적을 글이 없습니다") as NSString
            return
        }
        Task { await receive(text: text) }
    }

    /// 날짜가 붙었으면 달력이 맡는다. 아니면 종이가 잠깐 앞으로 나온다.
    private func announce(_ memo: Memo) {
        guard let day = Schedule(memo).day() else {
            windows.announce(memo)
            return
        }
        onScheduled(day)
    }
}
