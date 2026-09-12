import Foundation
import Testing
@testable import LazyMemoCore

// 시험 대상이 macOS 에만 있다 (`Process`).
#if os(macOS)
@Suite("UpdateInstaller")
struct UpdateInstallerTests {
    private let release = Release(
        version: SemanticVersion("0.2.0")!,
        download: URL(string: "https://example.test/lazymemo-0.2.0.zip")!,
        checksum: URL(string: "https://example.test/lazymemo-0.2.0.zip.sha256")!
    )
    private let payload = Data("새 판".utf8)
    private var payloadHex: String { UpdateInstaller.sha256(of: payload) }

    /// 시험마다 다른 자리를 준다 — swift-testing 은 한 묶음을 나란히 돌린다.
    private func workspace() -> URL {
        URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-update-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func cleanUp(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    /// `ditto` 자리에서 진짜 번들 하나를 만들어 준다 — 그래야 뒤의 검사가 돌아간다.
    private func fakeDitto(version: String) -> @Sendable (String, [String]) throws -> Int32 {
        { launch, arguments in
            guard launch.hasSuffix("ditto"), arguments.count >= 4 else { return 0 }
            let bundle = URL(filePath: arguments[3]).appending(path: "LazyMemo.app")
            try FileManager.default.createDirectory(
                at: bundle.appending(path: "Contents"), withIntermediateDirectories: true
            )
            let plist = try PropertyListSerialization.data(
                fromPropertyList: ["CFBundleShortVersionString": version],
                format: .xml, options: 0
            )
            try plist.write(to: bundle.appending(path: "Contents/Info.plist"))
            return 0
        }
    }

    // MARK: 순수한 조각들

    @Test("sha256 은 알려진 값과 같다")
    func hashesKnownVector() {
        #expect(UpdateInstaller.sha256(of: Data("abc".utf8))
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("`shasum` 이 뱉는 줄에서 앞의 것만 읽는다")
    func readsChecksumLine() {
        let hex = String(repeating: "a", count: 64)
        #expect(UpdateInstaller.hex(in: "\(hex)  lazymemo-0.2.0.zip") == hex)
        #expect(UpdateInstaller.hex(in: "\(hex)\n") == hex)
        #expect(UpdateInstaller.hex(in: "짧다  파일") == nil)
        #expect(UpdateInstaller.hex(in: String(repeating: "z", count: 64)) == nil)
        #expect(UpdateInstaller.hex(in: "") == nil)
    }

    @Test("자리 바꾸기는 지우고 쓰지 않는다 — 실패하면 도로 끌어온다")
    func swapScriptRollsBack() {
        let script = UpdateInstaller.swapScript(
            pid: 4321,
            staged: URL(filePath: "/tmp/lazymemo-update-0.2.0/unpacked/LazyMemo.app"),
            destination: URL(filePath: "/Applications/LazyMemo.app")
        )
        // 죽기를 기다린다.
        #expect(script.contains("kill -0 4321"))
        // 밀어 두고 쓴다.
        #expect(script.contains("mv \"/Applications/LazyMemo.app\" \"/Applications/LazyMemo.app.backup\""))
        // 실패하면 도로 끌어온다.
        #expect(script.contains("mv \"/Applications/LazyMemo.app.backup\" \"/Applications/LazyMemo.app\""))
        // **어느 갈래로 가든 앱은 다시 뜬다.**
        #expect(script.hasSuffix("open \"/Applications/LazyMemo.app\""))
    }

    /// 판 바꾸기를 **실제로 돌려 본다.** 두 경로(성공·실패) 모두 dest 가 살아 있어야 한다.
    private func runSwap(dittoFails: Bool) throws -> (destination: URL, backupLeft: Bool) {
        let root = workspace()
        let fm = FileManager.default
        let destination = root.appending(path: "LazyMemo.app", directoryHint: .isDirectory)
        let staged = root.appending(path: "work/unpacked/LazyMemo.app", directoryHint: .isDirectory)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        try fm.createDirectory(at: staged, withIntermediateDirectories: true)
        try Data("옛 판".utf8).write(to: destination.appending(path: "mark"))
        try Data("새 판".utf8).write(to: staged.appending(path: "mark"))

        let script = UpdateInstaller.swapScript(
            // 이미 없는 프로세스를 준다 — 기다림이 곧바로 끝난다.
            pid: 0x7FFF_FFFF,
            staged: staged,
            destination: destination,
            ditto: dittoFails ? "/usr/bin/false" : "/usr/bin/ditto",
            // 시험이 진짜 앱을 열게 두지 않는다.
            launcher: "/usr/bin/true"
        )
        let path = root.appending(path: "swap.sh")
        try Data(script.utf8).write(to: path)
        #expect(try UpdateInstaller.shell("/bin/sh", [path.path]) == 0)

        return (destination, fm.fileExists(atPath: destination.path + ".backup"))
    }

    @Test("스크립트를 실제로 돌리면 새 판이 자리에 앉는다")
    func swapScriptReplaces() throws {
        let result = try runSwap(dittoFails: false)
        let mark = try String(contentsOf: result.destination.appending(path: "mark"), encoding: .utf8)
        #expect(mark == "새 판")
        #expect(!result.backupLeft)
    }

    @Test("바꾸다 실패하면 옛 판이 도로 제자리로 온다 — 앱이 없어지지 않는다")
    func swapScriptRestoresOnFailure() throws {
        let result = try runSwap(dittoFails: true)
        let mark = try String(contentsOf: result.destination.appending(path: "mark"), encoding: .utf8)
        #expect(mark == "옛 판")
        #expect(!result.backupLeft)
    }

    // MARK: 준비 경로

    @Test("Homebrew 로 깔린 앱은 스스로 바꾸지 않는다")
    func refusesHomebrew() async {
        let installer = UpdateInstaller(fetch: { _ in Data() }, run: { _, _ in 0 })
        await #expect(throws: UpdateInstaller.Failure.notReplaceable(.homebrew)) {
            try await installer.stage(release, source: .homebrew)
        }
    }

    @Test("sha256 이 어긋나면 설치하지 않는다")
    func rejectsBadChecksum() async {
        let root = workspace()
        defer { cleanUp(root) }
        let installer = UpdateInstaller(
            fetch: { url in
                url.pathExtension == "sha256"
                    ? Data("\(String(repeating: "0", count: 64))  lazymemo-0.2.0.zip".utf8)
                    : payload
            },
            run: { _, _ in 0 },
            workRoot: root
        )
        await #expect(throws: UpdateInstaller.Failure.checksumMismatch) {
            try await installer.stage(release, source: .standalone)
        }
    }

    @Test("서명이 깨져 있으면 설치하지 않는다")
    func rejectsBrokenSignature() async {
        let root = workspace()
        defer { cleanUp(root) }
        let ditto = fakeDitto(version: "0.2.0")
        let installer = UpdateInstaller(
            fetch: { url in
                url.pathExtension == "sha256" ? Data("\(payloadHex)  z.zip".utf8) : payload
            },
            run: { launch, arguments in
                launch.hasSuffix("codesign") ? 1 : try ditto(launch, arguments)
            },
            workRoot: root
        )
        await #expect(throws: UpdateInstaller.Failure.signatureBroken) {
            try await installer.stage(release, source: .standalone)
        }
    }

    @Test("기다린 판이 아니면 설치하지 않는다")
    func rejectsWrongVersion() async {
        let root = workspace()
        defer { cleanUp(root) }
        let installer = UpdateInstaller(
            fetch: { url in
                url.pathExtension == "sha256" ? Data("\(payloadHex)  z.zip".utf8) : payload
            },
            run: fakeDitto(version: "0.1.0"),
            workRoot: root
        )
        await #expect(throws: UpdateInstaller.Failure.wrongVersion(expected: "0.2.0", found: "0.1.0")) {
            try await installer.stage(release, source: .standalone)
        }
    }

    @Test("셋을 다 통과하면 번들 자리를 돌려준다")
    func stagesWhenEverythingChecksOut() async throws {
        let root = workspace()
        defer { cleanUp(root) }
        let installer = UpdateInstaller(
            fetch: { url in
                url.pathExtension == "sha256" ? Data("\(payloadHex)  z.zip".utf8) : payload
            },
            run: fakeDitto(version: "0.2.0"),
            workRoot: root
        )
        let bundle = try await installer.stage(release, source: .standalone)
        #expect(bundle.lastPathComponent == "LazyMemo.app")
        #expect(UpdateInstaller.bundleVersion(at: bundle) == "0.2.0")
    }

    @Test("sha256 자산이 없는 옛 판도 나머지 검사는 다 받는다")
    func staysStrictWithoutChecksumAsset() async throws {
        let root = workspace()
        defer { cleanUp(root) }
        let bare = Release(version: release.version, download: release.download, checksum: nil)
        let installer = UpdateInstaller(
            fetch: { _ in payload }, run: fakeDitto(version: "0.2.0"), workRoot: root
        )
        #expect(try await installer.stage(bare, source: .standalone).lastPathComponent
            == "LazyMemo.app")
    }
}
#endif
