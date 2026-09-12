import Foundation
import LazyMemoCore
import Observation

/// 폴더 칩 — 차례는 이 기기의 설정, 이름은 파일에서 되살아난다 (`MemoFolders`).
/// 규칙은 맥의 `DrawerModel` 과 같다: 이름을 바꾸면 메모의 이름표도 따라가고,
/// 폴더를 지워도 메모는 없어지지 않는다 (이름표만 뗀다).
@Observable
final class FolderModel {
    private let store: MemoStore
    private let settings: SettingsStore
    private var listed: [String]

    var selected: String?

    init(store: MemoStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.listed = settings.current.folders ?? []
    }

    var names: [String] {
        MemoFolders.names(listed: listed, memos: store.memos)
    }

    func add(_ name: String) {
        guard let clean = MemoFolders.normalized(name) else { return }
        listed = MemoFolders.adding(clean, to: names)
        persist()
        selected = clean
    }

    func rename(_ old: String, to new: String) async {
        guard let renamed = MemoFolders.renaming(old, to: new, in: names),
              let clean = MemoFolders.normalized(new)
        else { return }
        listed = renamed
        persist()
        for memo in store.memos where memo.folder == old {
            _ = try? await store.update(memo.id, folder: .some(clean))
        }
        if selected == old { selected = clean }
    }

    func remove(_ name: String) async {
        listed = MemoFolders.removing(name, from: names)
        persist()
        for memo in store.memos where memo.folder == name {
            _ = try? await store.update(memo.id, folder: .some(nil))
        }
        if selected == name { selected = nil }
    }

    private func persist() {
        let snapshot = listed
        settings.update { $0.folders = snapshot }
    }
}
