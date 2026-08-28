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
}
