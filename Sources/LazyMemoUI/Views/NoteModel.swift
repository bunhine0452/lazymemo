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
    private(set) var images: [NoteImage] = []

    /// 본문이 가리키는 링크의 카드. 설정이 꺼져 있으면 비어 있다.
    private(set) var links: [LinkPreviewStore.Card] = []

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

    struct NoteImage: Identifiable, Equatable {
        let path: String
        let image: NSImage
        var id: String { path }
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
            var loaded: [NoteImage] = []
            for path in paths {
                guard !Task.isCancelled,
                      let url = store.url(for: path),
                      let image = NSImage(contentsOf: url)
                else { continue }
                loaded.append(NoteImage(path: path, image: Self.thumbnail(image)))
            }
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

    private static func thumbnail(_ image: NSImage, maxWidth: CGFloat = 480) -> NSImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let size = NSSize(width: maxWidth, height: (image.size.height * scale).rounded())

        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        thumbnail.unlockFocus()
        return thumbnail
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
        isDirty = true
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
            return
        }
        do {
            memo = try await store.update(memo.id, body: text)
            isDirty = false
        } catch {
            // 저장 실패는 조용히 넘어가면 안 된다. 다음 시도에서 다시 쓰도록
            // dirty 를 유지한다.
        }
    }

    // MARK: 속성 변경 — 즉시 반영

    func setColor(_ color: MemoColor) async {
        memo = (try? await store.update(memo.id, color: color)) ?? memo
    }

    func togglePin() async {
        memo = (try? await store.update(memo.id, pinned: !memo.pinned)) ?? memo
    }

    func clearSchedule() async {
        memo = (try? await store.update(memo.id, due: .some(nil), at: .some(nil))) ?? memo
    }

    func delete() async {
        await flush()
        try? await store.delete(memo.id)
    }
}
