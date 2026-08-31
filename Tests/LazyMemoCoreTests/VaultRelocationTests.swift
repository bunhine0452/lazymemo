import Foundation
import Testing
@testable import LazyMemoCore

/// 메모 폴더를 옮기는 길 (설계문서 §5.1, `{#vault-location}`).
///
/// README 는 처음부터 "이 폴더를 iCloud Drive 안으로 옮기면 동기화가 된다" 고
/// 적어 두었는데 **앱에는 그 폴더를 따라갈 길이 없었다.** 문서가 시킨 대로
/// Finder 에서 옮긴 사용자가 앱을 다시 켜면 기본 자리에 빈 폴더가 새로 생기고
/// 화면에는 메모가 한 장도 없다 — 문서를 믿은 사람이 전부 잃은 것으로 본다.
///
/// 여기서 재는 것은 **파일을 건드리기 전에 무엇을 할지 옳게 정하는가**다.
/// 잘못 정하면 메모 전부가 걸린다.
@Suite("메모 폴더 옮기기")
struct VaultRelocationTests {
    private func makeRoot() throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-move-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeVault(at url: URL, note: String = "메모 한 장") throws {
        let notes = url.appending(path: "notes/2026/08", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try note.write(
            to: notes.appending(path: "one.md", directoryHint: .notDirectory),
            atomically: true, encoding: .utf8
        )
    }

    private func makeFolder(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: 무엇을 할지 정하기

    @Test("빈 폴더를 고르면 그 안으로 옮긴다")
    func movesIntoAnEmptyFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let chosen = root.appending(path: "iCloud", directoryHint: .isDirectory)
        try makeVault(at: current)
        try makeFolder(at: chosen)

        let plan = VaultRelocation.plan(choosing: chosen, current: current)

        // 고른 폴더를 통째로 메모 폴더로 삼지 않는다 — 바탕화면을 고른 사람의
        // 바탕화면에 `notes/` 와 `.trash/` 를 쏟으면 안 된다.
        #expect(plan == .move(to: chosen.appending(path: "lazymemo", directoryHint: .isDirectory)))
    }

    @Test("이미 메모가 든 폴더를 고르면 옮기지 않고 그것을 쓴다")
    func adoptsAVaultThatIsAlreadyThere() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let moved = root.appending(path: "iCloud/lazymemo", directoryHint: .isDirectory)
        try makeVault(at: current)
        try makeVault(at: moved, note: "이미 옮겨 둔 메모")

        // Finder 로 이미 옮긴 사람이 그 폴더를 가리키는 경우다.
        #expect(VaultRelocation.plan(choosing: moved, current: current) == .adopt(moved))
        // 그 폴더의 부모를 골라도 같은 결론이어야 한다 — 사람은 둘 중 어느 것을
        // 고를지 매번 정확히 판단하지 않는다.
        #expect(VaultRelocation.plan(choosing: moved.deletingLastPathComponent(), current: current)
            == .adopt(moved))
    }

    @Test("쓰고 있는 폴더를 다시 고르면 아무 일도 하지 않는다")
    func recognizesTheCurrentFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        try makeVault(at: current)

        #expect(VaultRelocation.plan(choosing: current, current: current) == .alreadyThere)
    }

    /// 자기 안으로 옮기면 옮기는 도중에 원본이 사라진다.
    @Test("메모 폴더 안으로는 옮기지 않는다")
    func refusesToMoveIntoItself() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let inside = current.appending(path: "notes", directoryHint: .isDirectory)
        try makeVault(at: current)

        guard case .refuse = VaultRelocation.plan(choosing: inside, current: current) else {
            Issue.record("자기 안으로 옮기는 것을 막지 않았다")
            return
        }
    }

    @Test("남의 것이 들어 있는 자리에는 옮기지 않는다")
    func refusesToOverwriteSomethingElse() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let chosen = root.appending(path: "Somewhere", directoryHint: .isDirectory)
        try makeVault(at: current)
        // 고른 자리에 이미 `lazymemo` 라는 다른 폴더가 있다.
        try makeFolder(at: chosen.appending(path: "lazymemo/사진", directoryHint: .isDirectory))

        guard case .refuse = VaultRelocation.plan(choosing: chosen, current: current) else {
            Issue.record("남의 폴더를 덮어쓸 뻔했다")
            return
        }
    }

    // MARK: 정말로 옮기기

    @Test("옮기면 메모 파일이 통째로 따라간다")
    func carriesTheFilesAlong() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let chosen = root.appending(path: "iCloud", directoryHint: .isDirectory)
        try makeVault(at: current, note: "치과 예약")
        try makeFolder(at: chosen)

        let plan = VaultRelocation.plan(choosing: chosen, current: current)
        let moved = try VaultRelocation.perform(plan, from: current)

        let landed = moved.appending(path: "notes/2026/08/one.md", directoryHint: .notDirectory)
        #expect(try String(contentsOf: landed, encoding: .utf8) == "치과 예약")
        // 옛 자리는 남지 않는다 — 남으면 다음에 켤 때 어느 쪽이 정본인지 모른다.
        #expect(!FileManager.default.fileExists(atPath: current.path(percentEncoded: false)))
    }

    @Test("이미 있는 폴더를 쓸 때는 파일을 건드리지 않는다")
    func adoptingMovesNothing() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appending(path: "Documents/lazymemo", directoryHint: .isDirectory)
        let moved = root.appending(path: "iCloud/lazymemo", directoryHint: .isDirectory)
        try makeVault(at: current, note: "여기 것")
        try makeVault(at: moved, note: "저기 것")

        let landed = try VaultRelocation.perform(
            VaultRelocation.plan(choosing: moved, current: current), from: current
        )

        #expect(landed == moved)
        // 둘 다 그대로 있다. 옮기지 않기로 한 것이므로 지우지도 않는다.
        #expect(FileManager.default.fileExists(atPath: current.path(percentEncoded: false)))
        let file = moved.appending(path: "notes/2026/08/one.md", directoryHint: .notDirectory)
        #expect(try String(contentsOf: file, encoding: .utf8) == "저기 것")
    }

    // MARK: 다시 켰을 때

    @Test("설정에 적힌 폴더를 다음 실행이 그대로 쓴다")
    func remembersTheMovedFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let moved = root.appending(path: "iCloud/lazymemo", directoryHint: .isDirectory)
        try makeVault(at: moved)
        try makeFolder(at: support)

        let settings = SettingsStore(
            location: support.appending(path: "settings.json", directoryHint: .notDirectory)
        )
        settings.update { $0.vaultPath = moved.path(percentEncoded: false) }

        #expect(Settings.storedVaultPath(inSupport: support) == moved.path(percentEncoded: false))
    }

    @Test("적어 둔 폴더가 없으면 기본 자리로 돌아가되 그 사실을 들고 나온다")
    func reportsAMissingFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        try makeFolder(at: support)
        let settings = SettingsStore(
            location: support.appending(path: "settings.json", directoryHint: .notDirectory)
        )
        // 외장 디스크를 안 꽂았거나 iCloud 가 아직 안 내려온 자리.
        settings.update { $0.vaultPath = "/Volumes/없는디스크/lazymemo" }

        // 조용히 빈 폴더를 만들면 사용자는 메모가 전부 사라진 것으로 본다.
        #expect(Settings.storedVaultPath(inSupport: support) == "/Volumes/없는디스크/lazymemo")
        #expect(!AppPaths.isDirectory(URL(filePath: "/Volumes/없는디스크/lazymemo")))
    }

    @Test("검증용 환경변수가 설정보다 세다 — 시험이 진짜 메모를 건드리지 않게")
    func environmentOverrideWins() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let resolved = AppPaths.resolve(
            environment: [AppPaths.vaultEnvironmentKey: root.path(percentEncoded: false)]
        )

        #expect(resolved.paths.vault.lastPathComponent == "vault")
        #expect(resolved.missingVault == nil)
    }
}
