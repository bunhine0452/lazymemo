import CryptoKit
import Foundation

// `Process` 는 macOS 에만 있다. 폰의 판 갈이는 스토어의 몫이라 이 파일 전체가 맥의 것이다.
#if os(macOS)
/// 내려받은 새 판으로 이 앱을 바꾼다.
///
/// **자기를 바꾸는 일이라, 실패했을 때 앱이 없어지면 안 된다.** 그래서 순서가
/// 이렇다 — 받고, 대조하고, 풀고, 서명을 보고, 판을 보고, **그 전부가 통과한
/// 뒤에야** 자리를 바꾼다. 자리를 바꾸는 마지막 걸음도 지우고 쓰는 것이 아니라
/// **옆으로 밀어 두고 쓰고, 실패하면 도로 끌어온다** (`swapScript`).
///
/// 검증을 셋이나 두는 이유는 이 앱이 **공증받지 않았기** 때문이다 (§12.2).
/// 공증된 앱이면 Gatekeeper 가 대신 봐 주지만 여기서는 그 그물이 없다. 그래서
/// 우리가 본다 — sha256 은 받다 만 파일을, `codesign` 은 풀다 깨진 번들을,
/// 판 번호는 «다른 것을 받았다» 를 잡는다.
public struct UpdateInstaller: Sendable {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notReplaceable(InstallSource)
        case checksumMismatch
        case unpackFailed
        case signatureBroken
        case wrongVersion(expected: String, found: String)
        case notWritable(String)

        public var description: String {
            switch self {
            case .notReplaceable(.homebrew):
                L("Homebrew 로 설치한 앱입니다 — 터미널에서 `brew upgrade --cask lazymemo`")
            case .notReplaceable:
                L("이 앱은 스스로 바꿀 수 없는 자리에 있습니다")
            case .checksumMismatch:
                L("받은 파일이 온전하지 않습니다 — 다시 시도해 보세요")
            case .unpackFailed:
                L("받은 파일을 풀지 못했습니다")
            case .signatureBroken:
                L("받은 앱의 서명이 깨져 있습니다 — 설치하지 않았습니다")
            case .wrongVersion(let expected, let found):
                L("받은 앱이 \(found) 입니다 (\(expected) 를 기다렸습니다)")
            case .notWritable(let path):
                L("\(path) 에 쓸 수 없습니다")
            }
        }
    }

    public typealias Fetch = @Sendable (URL) async throws -> Data

    let fetch: Fetch
    let run: @Sendable (String, [String]) throws -> Int32
    /// 받은 것을 펼쳐 두는 자리. 시험이 서로의 폴더를 지우지 않도록 밖에서 받는다.
    let workRoot: URL

    public init(
        fetch: @escaping Fetch,
        run: @escaping @Sendable (String, [String]) throws -> Int32 = Self.shell,
        workRoot: URL = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
    ) {
        self.fetch = fetch
        self.run = run
        self.workRoot = workRoot
    }

    /// 새 판을 임시 자리에 **준비만** 한다. 자리 바꾸기는 앱이 죽은 뒤라 여기서 하지 않는다.
    ///
    /// 돌려주는 것은 검사를 다 통과한 번들의 자리다.
    public func stage(_ release: Release, source: InstallSource) async throws -> URL {
        guard source == .standalone else { throw Failure.notReplaceable(source) }

        let work = workRoot
            .appending(path: "lazymemo-update-\(release.version)", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: work)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let archive = work.appending(path: "lazymemo.zip")
        try await fetch(release.download).write(to: archive)

        // ① 받다 만 파일을 잡는다.
        if let checksumURL = release.checksum {
            let expected = Self.hex(in: String(decoding: try await fetch(checksumURL), as: UTF8.self))
            let actual = Self.sha256(of: try Data(contentsOf: archive))
            guard let expected, expected.caseInsensitiveCompare(actual) == .orderedSame else {
                throw Failure.checksumMismatch
            }
        }

        let unpacked = work.appending(path: "unpacked", directoryHint: .isDirectory)
        guard (try? run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])) == 0,
              let bundle = try? FileManager.default
                  .contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)
                  .first(where: { $0.pathExtension == "app" })
        else { throw Failure.unpackFailed }

        // ② 풀다 깨진 번들을 잡는다. 공증이 없으니 이 그물은 우리가 친다.
        guard (try? run("/usr/bin/codesign", ["--verify", "--deep", "--strict", bundle.path])) == 0
        else { throw Failure.signatureBroken }

        // ③ «다른 것을 받았다» 를 잡는다.
        let found = Self.bundleVersion(at: bundle)
        guard found == release.version.description else {
            throw Failure.wrongVersion(expected: release.version.description, found: found ?? L("알 수 없음"))
        }

        return bundle
    }

    // MARK: 순수한 조각들 — 여기가 시험이 닿는 곳이다

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// `shasum -a 256` 이 뱉는 `<hex>  <이름>` 에서 앞의 것만.
    static func hex(in line: String) -> String? {
        guard let token = line.split(whereSeparator: \.isWhitespace).first else { return nil }
        let text = String(token)
        guard text.count == 64, text.allSatisfy(\.isHexDigit) else { return nil }
        return text
    }

    static func bundleVersion(at bundle: URL) -> String? {
        let plist = bundle.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let object = try? PropertyListSerialization
                  .propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return object["CFBundleShortVersionString"] as? String
    }

    /// 앱이 죽기를 기다렸다가 자리를 바꾸고 다시 여는 스크립트.
    ///
    /// **지우고 쓰지 않는다.** 옆으로 밀어 두고 쓰고, 실패하면 밀어 둔 것을 도로
    /// 끌어온다 — 여기서 지웠다가 `ditto` 가 실패하면 사용자에게는 앱이 통째로
    /// 사라진 것으로 보이고, 그건 업데이트가 아니라 사고다. 어느 갈래로 가든
    /// 마지막 줄은 `open` 이라 **앱은 반드시 다시 뜬다.**
    /// `ditto` 와 `open` 을 밖에서 받는 이유는 **이 스크립트를 시험이 실제로
    /// 돌려 보기 위해서**다. 여기는 «잘 되겠지» 로 두면 안 되는 유일한 자리다 —
    /// 틀리면 사용자의 앱이 없어지고, 그 사실은 앱이 없어진 뒤에 드러난다.
    public static func swapScript(
        pid: Int32,
        staged: URL,
        destination: URL,
        ditto: String = "/usr/bin/ditto",
        launcher: String = "/usr/bin/open"
    ) -> String {
        let backup = destination.path + ".backup"
        return """
            #!/bin/sh
            # lazymemo 판 바꾸기 — 앱이 스스로는 못 하는 마지막 걸음.
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            if mv "\(destination.path)" "\(backup)"; then
                if \(ditto) "\(staged.path)" "\(destination.path)"; then
                    rm -rf "\(backup)"
                else
                    rm -rf "\(destination.path)"
                    mv "\(backup)" "\(destination.path)"
                fi
            fi
            rm -rf "\(staged.deletingLastPathComponent().deletingLastPathComponent().path)"
            \(launcher) "\(destination.path)"
            """
    }

    @Sendable public static func shell(_ launchPath: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
#endif
