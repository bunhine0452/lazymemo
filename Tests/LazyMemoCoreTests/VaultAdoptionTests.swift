import Foundation
import Testing
@testable import LazyMemoCore

/// 밖에서 떨어진 파일을 받아 앉히는 규칙 (`{#vault-tolerance}`).
///
/// 이것이 없으면 아이폰 단축어가 떨군 메모는 **조용히 무시된다** — 폴더에는
/// 있는데 앱에는 없는 상태이고, 사용자에게는 «적었는데 사라졌다» 로 보인다.
@Suite("낯선 파일 받아 앉히기")
struct VaultAdoptionTests {
    private func makeVault() throws -> (MemoVault, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-adopt-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (MemoVault(paths: paths), paths)
    }

    private func drop(_ text: String, named name: String, into paths: AppPaths) throws {
        try FileManager.default.createDirectory(at: paths.notes, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: paths.notes.appending(path: name))
    }

    @Test("frontmatter 없는 맨 글도 메모가 된다 — 완성을 요구하지 않는다")
    func adoptsPlainMarkdown() async throws {
        let (vault, paths) = try makeVault()
        try drop("장보기\n- 우유", named: "아이폰메모.md", into: paths)

        let adopted = try await vault.adopt()
        #expect(adopted.count == 1)
        #expect(adopted.first?.body == "장보기\n- 우유")

        // 정본 이름으로 앉고, 낯선 이름은 사라진다.
        let all = try await vault.loadAll()
        #expect(all.count == 1)
        #expect(!FileManager.default.fileExists(atPath: paths.notes.appending(path: "아이폰메모.md").path))
    }

    @Test("id 만 없는 frontmatter 는 나머지를 살린다")
    func keepsFrontmatterWithoutID() async throws {
        let (vault, paths) = try makeVault()
        try drop("""
            ---
            due: 2026-09-01
            place: 강남역
            ---
            치과
            """, named: "shortcut-2026-09-01.md", into: paths)

        let adopted = try await vault.adopt()
        #expect(adopted.first?.due == CalendarDate(year: 2026, month: 9, day: 1))
        #expect(adopted.first?.place == "강남역")
        #expect(adopted.first?.body == "치과")
    }

    @Test("우리 이름의 파일은 건드리지 않는다")
    func leavesCanonicalFilesAlone() async throws {
        let (vault, paths) = try makeVault()
        let memo = Memo(body: "이미 우리 것")
        _ = try await vault.save(memo)

        #expect(try await vault.adopt().isEmpty)
        #expect(try await vault.loadAll().count == 1)
        _ = paths
    }

    @Test("빈 파일은 받지도 지우지도 않는다 — 쓰다 만 것일 수 있다")
    func ignoresEmptyFiles() async throws {
        let (vault, paths) = try makeVault()
        try drop("   \n", named: "빈것.md", into: paths)

        #expect(try await vault.adopt().isEmpty)
        #expect(FileManager.default.fileExists(atPath: paths.notes.appending(path: "빈것.md").path))
    }

    @Test("두 번 받아 앉히지 않는다 — 스캔마다 불어나면 안 된다")
    func adoptsOnlyOnce() async throws {
        let (vault, paths) = try makeVault()
        try drop("한 번만", named: "떨어진것.md", into: paths)

        #expect(try await vault.adopt().count == 1)
        #expect(try await vault.adopt().isEmpty)
        #expect(try await vault.loadAll().count == 1)
    }
}
