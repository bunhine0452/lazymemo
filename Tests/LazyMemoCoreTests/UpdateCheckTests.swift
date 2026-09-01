import Foundation
import Testing
@testable import LazyMemoCore

@Suite("UpdateCheck")
struct UpdateCheckTests {
    private func feed(tag: String, assets: [String]) -> Data {
        let list = assets.map {
            """
            {"name":"\($0)","browser_download_url":"https://example.test/\($0)"}
            """
        }.joined(separator: ",")
        return Data("""
            {"tag_name":"\(tag)",
             "html_url":"https://github.com/bunhine0452/lazymemo/releases/tag/\(tag)",
             "assets":[\(list)]}
            """.utf8)
    }

    @Test("태그와 zip 자산을 읽는다")
    func readsRelease() throws {
        let release = try UpdateCheck.release(
            from: feed(tag: "v0.2.0", assets: ["lazymemo-0.2.0.zip"])
        )
        #expect(release.version == SemanticVersion("0.2.0"))
        #expect(release.download.lastPathComponent == "lazymemo-0.2.0.zip")
        #expect(release.notes?.absoluteString.hasSuffix("v0.2.0") == true)
        #expect(release.checksum == nil)
    }

    @Test("sha256 자산이 있으면 함께 읽는다")
    func readsChecksum() throws {
        let release = try UpdateCheck.release(
            from: feed(tag: "v0.2.0", assets: ["lazymemo-0.2.0.zip", "lazymemo-0.2.0.zip.sha256"])
        )
        #expect(release.checksum?.lastPathComponent == "lazymemo-0.2.0.zip.sha256")
        #expect(release.download.lastPathComponent == "lazymemo-0.2.0.zip")
    }

    @Test("내려받을 앱이 없으면 그렇게 말한다 — 조용히 «최신입니다» 가 되면 안 된다")
    func failsWithoutAsset() {
        #expect(throws: UpdateCheck.Failure.noAsset("0.2.0")) {
            try UpdateCheck.release(from: feed(tag: "v0.2.0", assets: ["소스코드.zip"]))
        }
    }

    @Test("모양이 다른 응답은 오류다")
    func failsOnJunk() {
        #expect(throws: UpdateCheck.Failure.unreadable) {
            try UpdateCheck.release(from: Data("잘못된 응답".utf8))
        }
        #expect(throws: UpdateCheck.Failure.noVersion("latest")) {
            try UpdateCheck.release(from: feed(tag: "latest", assets: ["lazymemo-1.zip"]))
        }
    }

    @Test("같은 판은 새 판이 아니다")
    func sameVersionIsNotNewer() throws {
        let release = try UpdateCheck.release(
            from: feed(tag: "v0.1.0", assets: ["lazymemo-0.1.0.zip"])
        )
        #expect(UpdateCheck.newer(than: SemanticVersion("0.1.0")!, in: release) == nil)
        #expect(UpdateCheck.newer(than: SemanticVersion("0.2.0")!, in: release) == nil)
        #expect(UpdateCheck.newer(than: SemanticVersion("0.0.9")!, in: release) != nil)
    }

    @Test("받아오는 함수를 주입해 네트워크 없이 전체 경로를 돈다")
    func latestUsesInjectedFetch() async throws {
        let data = feed(tag: "v9.9.9", assets: ["lazymemo-9.9.9.zip"])
        let release = try await UpdateCheck.latest { url in
            #expect(url == UpdateCheck.feed)
            return data
        }
        #expect(release.version == SemanticVersion("9.9.9"))
    }
}

@Suite("InstallSource")
struct InstallSourceTests {
    @Test("brew 가 놓은 자리에 있고 Caskroom 이 있으면 brew 의 것이다")
    func detectsHomebrew() {
        let source = InstallSource.detect(bundlePath: "/Applications/LazyMemo.app") {
            $0 == "/opt/homebrew/Caskroom/lazymemo"
        }
        #expect(source == .homebrew)
        #expect(source.advice == "brew upgrade --cask lazymemo")
    }

    @Test("brew 가 깔려 있어도 다른 자리의 앱은 brew 의 것이 아니다")
    func standaloneOutsideApplications() {
        // 손으로 받아 둔 앱까지 brew 에 미루면 그 사람은 영영 업데이트를 못 받는다.
        let source = InstallSource.detect(bundlePath: "/Users/me/dist/LazyMemo.app") { _ in true }
        #expect(source == .standalone)
    }

    @Test("Caskroom 이 없으면 앱이 스스로 바꾼다")
    func standaloneWithoutCaskroom() {
        #expect(InstallSource.detect(bundlePath: "/Applications/LazyMemo.app") { _ in false }
            == .standalone)
    }

    @Test("swift run 으로 도는 중에는 바꿀 번들이 없다")
    func development() {
        #expect(InstallSource.detect(bundlePath: "/repo/.build/debug/LazyMemo.app") { _ in true }
            == .development)
        #expect(InstallSource.detect(bundlePath: "/repo/.build/debug/LazyMemo") { _ in true }
            == .development)
        #expect(InstallSource.detect(bundlePath: "/repo/.build/debug/LazyMemo") { _ in true }.advice
            == nil)
    }
}
