import Foundation
import Testing
@testable import LazyMemoCore

@Suite("AppPaths")
struct AppPathsTests {
    private let paths = AppPaths(
        vault: URL(filePath: "/tmp/lazymemo-test/vault", directoryHint: .isDirectory),
        support: URL(filePath: "/tmp/lazymemo-test/support", directoryHint: .isDirectory)
    )

    @Test("정본과 파생물이 서로 다른 뿌리에 놓인다")
    func vaultAndSupportAreSeparate() {
        #expect(paths.notes.path(percentEncoded: false) == "/tmp/lazymemo-test/vault/notes/")
        #expect(paths.trash.path(percentEncoded: false) == "/tmp/lazymemo-test/vault/.trash/")
        #expect(paths.index.path(percentEncoded: false) == "/tmp/lazymemo-test/support/index.sqlite")
        #expect(paths.layout.path(percentEncoded: false) == "/tmp/lazymemo-test/support/layout.json")
    }

    @Test("메모 디렉터리는 연/월로 갈라진다")
    func notesDirectoryIsSplitByYearMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!

        let directory = paths.notesDirectory(for: date, calendar: calendar)

        #expect(directory.path(percentEncoded: false) == "/tmp/lazymemo-test/vault/notes/2026/08/")
    }

    @Test("한 자리 월은 0 으로 채운다")
    func monthIsZeroPadded() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!

        #expect(paths.notesDirectory(for: date, calendar: calendar).lastPathComponent == "01")
    }

    @Test("디렉터리 생성은 두 번 호출해도 안전하다")
    func createDirectoriesIsIdempotent() throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-\(UUID().uuidString)", directoryHint: .isDirectory)
        let subject = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try subject.createDirectories()
        try subject.createDirectories()

        #expect(FileManager.default.fileExists(atPath: subject.notes.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: subject.trash.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: subject.support.path(percentEncoded: false)))
    }

    // MARK: iCloud 컨테이너

    private let container = URL(filePath: "/tmp/lazymemo-test/iCloud~lazymemo", directoryHint: .isDirectory)

    @Test("컨테이너가 있으면 그 Documents 가 Vault 가 되고 파생물은 제자리에 남는다")
    func cloudContainerBecomesVault() {
        let resolved = AppPaths.resolveCloud(container: container, environment: [:])

        #expect(resolved.usingCloud)
        #expect(resolved.paths.vault.path(percentEncoded: false) == "/tmp/lazymemo-test/iCloud~lazymemo/Documents/")
        #expect(resolved.paths.support == AppPaths.resolve(environment: [:]).paths.support)
    }

    @Test("컨테이너가 없으면 기본 자리로 가되 그 사실을 들고 나온다")
    func noContainerFallsBackHonestly() {
        let resolved = AppPaths.resolveCloud(container: nil, environment: [:])

        #expect(!resolved.usingCloud)
        #expect(resolved.paths == AppPaths.resolve(environment: [:]).paths)
    }

    @Test("App Store 판의 기본 자리는 컨테이너 — 설정에 아무것도 없을 때만")
    func storeBuildDefaultsToCloud() {
        let resolved = AppPaths.resolve(environment: [:], cloudContainer: container)

        #expect(resolved.paths.vault.path(percentEncoded: false) == "/tmp/lazymemo-test/iCloud~lazymemo/Documents/")
        #expect(resolved.paths.support == AppPaths.resolve(environment: [:]).paths.support)
        #expect(resolved.missingVault == nil)
    }

    @Test("LAZYMEMO_VAULT 는 컨테이너보다 세다 — 시험이 진짜 iCloud 를 건드리면 안 된다")
    func environmentOverrideBeatsContainer() {
        let environment = [AppPaths.vaultEnvironmentKey: "/tmp/lazymemo-test/override"]
        let resolved = AppPaths.resolveCloud(container: container, environment: environment)

        #expect(!resolved.usingCloud)
        #expect(resolved.paths.vault.path(percentEncoded: false) == "/tmp/lazymemo-test/override/vault/")
    }
}
