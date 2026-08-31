import AppKit
import Foundation
import LazyMemoCore
import Observation

/// 메모 창 하나의 상태와 자동 저장 (설계문서 §8).
///
/// **저장 버튼이 없다.** 입력이 멈추면 디바운스 후 저장하고, 창이 닫히거나
/// 앱이 종료될 때 즉시 flush 한다. "생각 → 저장" 조작 수를 2회 이내로 두는
/// 성능 예산(§11)이 이 클래스에 걸려 있다.
@MainActor
@Observable
final class NoteModel {
    private(set) var memo: Memo
    var text: String

    /// 타자가 멈춘 뒤 이만큼 지나면 쓴다. 짧으면 디스크를 두들기고,
    /// 길면 앱이 죽었을 때 잃는 양이 늘어난다.
    private static let autosaveDelay: Duration = .milliseconds(600)

    /// 본문이 참조하는 사진들. 글 아래에 붙는다.
    private(set) var images: [AttachedImage] = []

    /// 본문이 가리키는 링크의 카드. 설정이 꺼져 있으면 비어 있다.
    private(set) var links: [LinkPreviewStore.Card] = []

    /// 나이를 재는 기준 시각 (`MemoAge`, 철학 3).
    ///
    /// 이것이 없을 때는 창이 다시 그려질 이유가 없어서 **어제 손댄 메모가 계속
    /// 오늘 것으로** 보였다. 상주 앱이라 그 상태가 며칠씩 갔고, "오래된 것은
    /// 스스로 물러난다" 가 실사용에서 통째로 죽어 있었다. `DayClock` 이 넘긴다.
    private(set) var asOf = Date()

    /// 방금 이 종이에서 지운 메모. **되돌리는 줄이 종이 위에 떠 있는 동안만** 값이 있다 (D6).
    ///
    /// 지우는 길이 셋인데(종이·메뉴 목록·빠른 입력) 되돌리는 줄이 그 자리에
    /// 생기는 것은 둘뿐이었다. 종이의 휴지통만 창이 소리 없이 사라지고 화면에
    /// 흔적이 하나도 안 남았다 — 잘못 눌렀다는 것을 아는 순간은 지운 직후인데,
    /// 그때 되돌리려면 메뉴바 아이콘을 눌러 메뉴를 뒤져야 했다. 지우기는 한
    /// 번인데 되돌리기가 셋이면 그 휴지통은 못 누르는 버튼이다.
    private(set) var justDeleted: Memo?

    /// 되돌리는 줄이 머무는 시간. 달력의 되돌리기와 같은 값이다 — 이보다
    /// 길면 지운 종이가 화면에 눌어붙고, 짧으면 놓친다.
    private static let undoWindow: Duration = .seconds(8)
    private var undoTask: Task<Void, Never>?

    /// 되돌리는 줄이 사라졌다 — 이제 창을 거둬도 된다 (`NoteWindowManager`).
    var onDeletionSettled: () -> Void = {}

    /// 마지막 저장이 실패했는가. **종이가 이것을 스스로 말한다.**
    ///
    /// 저장 버튼이 없으므로 "적혔겠지" 가 기본 믿음이고, 안 적힌 글도 화면에는
    /// 그대로 있다. 둘이 똑같이 보이는 채로 창을 닫으면 그대로 잃는다.
    private(set) var isUnsaved = false

    /// 실패한 뒤 다시 해 보기까지. 손이 멈춘 다음에는 다시 쓸 계기가 없어서,
    /// 그냥 두면 사용자가 또 타자를 치기 전까지 영영 안 적힌다.
    private static let retryDelay: Duration = .seconds(3)
    /// 더 해 볼 횟수. 끝없이 두들기면 디스크가 찬 동안 3초마다 도는 고리가
    /// 된다 — 표시는 남기고 손은 멈춘다. 다시 치면 다시 센다.
    private static let retryBudget = 3
    private var retriesLeft = NoteModel.retryBudget

    private let store: MemoStore
    private let attachments: AttachmentStore
    private let previews: LinkPreviewStore
    private var saveTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var linkTask: Task<Void, Never>?
    private var isDirty = false

    init(memo: Memo, store: MemoStore, previews: LinkPreviewStore) {
        self.memo = memo
        self.text = memo.body
        self.store = store
        self.attachments = store.attachments
        self.previews = previews
        reloadImages()
        reloadLinks()
    }

    // MARK: 붙여넣기

    /// 사진을 Vault 안의 진짜 파일로 저장하고 본문에 넣을 마크다운을 돌려준다.
    func markdown(forPastedImage data: Data, fileExtension: String) -> String? {
        guard let path = try? attachments.save(data, fileExtension: fileExtension) else { return nil }
        // 앞뒤로 줄을 띄운다. 그림이 글줄 사이에 끼어 있으면 읽기 나쁘다.
        return "\n![](\(path))\n"
    }

    func markdown(forPastedLink url: URL) -> String {
        LinkLabel.markdown(for: url)
    }

    /// 붙여 둔 사진의 원본 파일. 펼쳐 볼 때만 읽는다.
    ///
    /// 화면에 들고 있는 것은 480px 로 줄인 그림이라(§11) 원본 크기로 보려면
    /// 다시 읽어야 한다. 열 장을 원본으로 들고 있으면 메모리 예산이 무너지므로
    /// **보겠다는 뜻을 밝힌 그 순간에만** 읽는 편이 맞다.
    func originalURL(for attachment: AttachedImage) -> URL? {
        attachments.url(for: attachment.path)
    }

    /// 본문에서 사진 참조를 읽어 실제 파일을 불러온다.
    ///
    /// 큰 사진을 원본 크기로 들고 있으면 메모 열 장에 예산(§11)이 무너지므로
    /// 화면에 필요한 크기로 줄여서 담는다.
    private func reloadImages() {
        let paths = MarkdownScanner.imagePaths(in: text)
        guard paths != images.map(\.path) else { return }

        loadTask?.cancel()
        guard !paths.isEmpty else {
            images = []
            return
        }

        let store = attachments
        loadTask = Task { [weak self] in
            let loaded = AttachedImages.load(paths, from: store)
            guard !Task.isCancelled else { return }
            self?.images = loaded
        }
    }

    /// 본문의 링크를 카드로 펼친다.
    ///
    /// 이미 알고 있는 것을 먼저 보이고, 모르는 것만 가져온다 — 메모를 열 때마다
    /// 화면이 비었다가 채워지면 그것 자체가 불편이다.
    private func reloadLinks() {
        guard previews.isEnabled else {
            links = []
            return
        }

        let urls = MarkdownScanner.linkDestinations(in: text).compactMap(URL.init(string:))
        guard urls.map(\.absoluteString) != links.map(\.url.absoluteString) else { return }

        linkTask?.cancel()
        links = urls.compactMap { previews.cached($0) }
        guard !urls.isEmpty else { return }

        linkTask = Task { [weak self] in
            var loaded: [LinkPreviewStore.Card] = []
            for url in urls {
                guard !Task.isCancelled, let card = await self?.previews.fetch(url) else { continue }
                loaded.append(card)
            }
            guard !Task.isCancelled, !loaded.isEmpty else { return }
            self?.links = loaded
        }
    }

    /// 하루가 바뀌었다 — 나이를 다시 재게 한다 (`DayClock`).
    func dayChanged(now: Date = Date()) {
        asOf = now
    }

    // MARK: 외부 변경 반영

    /// 파일이 밖에서 바뀌었을 때(MCP·텍스트 에디터) 창에 반영한다.
    /// 사용자가 편집 중이면 덮어쓰지 않는다 — 타이핑을 빼앗기는 것보다
    /// 잠시 어긋나 있는 편이 낫다.
    func adopt(_ updated: Memo) {
        memo = updated
        guard !isDirty else { return }
        if text != updated.body {
            text = updated.body
            reloadImages()
            reloadLinks()
        }
    }

    // MARK: 편집

    func edited(_ newText: String) {
        // 지운 종이에는 더 적지 않는다. 되돌리는 줄이 떠 있는 동안 글자가
        // 들어오면 그것은 휴지통 안의 파일에 쓰는 일이 된다.
        guard justDeleted == nil else { return }
        isDirty = true
        // 손이 다시 움직였으면 다시 세어 준다 — 아까 디스크가 찼더라도
        // 지금은 아닐 수 있고, 사용자는 방금 이 글을 남기겠다고 말했다.
        retriesLeft = Self.retryBudget
        reloadImages()
        reloadLinks()
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.persistBody()
        }
    }

    /// 창을 닫거나 앱이 꺼질 때. 기다릴 수 없으므로 지금 쓴다.
    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        await persistBody()
    }

    private func persistBody() async {
        guard isDirty, text != memo.body else {
            isDirty = false
            isUnsaved = false
            return
        }
        do {
            memo = try await store.update(memo.id, body: text)
            isDirty = false
            isUnsaved = false
            retriesLeft = Self.retryBudget
        } catch {
            // 저장 실패는 조용히 넘어가면 안 된다. `dirty` 를 유지해 다음
            // 시도에서 다시 쓰고, **종이가 그 사실을 스스로 말한다** —
            // 예전에는 여기가 빈 catch 라 실패가 화면 어디에도 안 나타났다.
            isUnsaved = true
            retryLater()
        }
    }

    /// 한 번 더 해 본다. 예산이 다하면 손을 멈추고 표시만 남긴다.
    private func retryLater() {
        guard retriesLeft > 0 else { return }
        retriesLeft -= 1
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.retryDelay)
            guard !Task.isCancelled else { return }
            await self?.persistBody()
        }
    }

    // MARK: 속성 변경 — 즉시 반영

    func setColor(_ color: MemoColor) async {
        memo = (try? await store.update(memo.id, color: color)) ?? memo
    }

    func togglePin() async {
        memo = (try? await store.update(memo.id, pinned: !memo.pinned)) ?? memo
    }

    /// 이 종이를 지운다. **창은 그 자리에 남아 되돌리는 줄을 든다.**
    func delete() async {
        await flush()
        // 지우기 **전에** 표시해 둔다. 지우는 순간 목록이 바뀌고 창을 거두는
        // 쪽(`NoteWindowManager.sync`)이 곧바로 이 종이를 없애는데, 그 판단이
        // 이 표시를 보고 갈린다 — 한 박자라도 늦으면 창이 먼저 사라진다.
        justDeleted = memo
        guard (try? await store.delete(memo.id)) != nil else {
            justDeleted = nil
            return
        }
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.settleDeletion()
        }
    }

    /// 방금 지운 것을 되살린다. 종이는 있던 자리에 그대로 있다.
    func restoreDeleted() async {
        guard let deleted = justDeleted else { return }
        undoTask?.cancel()
        try? await store.restore(deleted.id)
        justDeleted = nil
    }

    /// 되돌릴 시간이 지났다. 이제 창을 거둔다.
    private func settleDeletion() {
        guard justDeleted != nil else { return }
        justDeleted = nil
        onDeletionSettled()
    }
}
