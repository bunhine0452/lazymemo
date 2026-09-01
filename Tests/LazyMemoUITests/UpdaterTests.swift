import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

@MainActor
@Suite("Updater")
struct UpdaterTests {
    private func settings() -> SettingsStore {
        let directory = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-updater-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SettingsStore(location: directory.appending(path: "settings.json"))
    }

    private func feed(_ tag: String) -> Data {
        Data("""
            {"tag_name":"\(tag)","html_url":"https://example.test/\(tag)",
             "assets":[{"name":"lazymemo-\(tag.dropFirst()).zip",
                        "browser_download_url":"https://example.test/lazymemo.zip"}]}
            """.utf8)
    }

    private func updater(
        _ source: InstallSource, tag: String = "v99.0.0", settings store: SettingsStore? = nil
    ) -> Updater {
        let data = feed(tag)
        return Updater(settings: store ?? settings(), source: source, fetch: { _ in data })
    }

    @Test("새 판이 있으면 그것을 든다")
    func findsNewer() async {
        let updater = updater(.standalone)
        await updater.check()
        #expect(updater.state == .found(
            Release(version: SemanticVersion("99.0.0")!,
                    download: URL(string: "https://example.test/lazymemo.zip")!,
                    notes: URL(string: "https://example.test/v99.0.0")!)
        ))
    }

    @Test("지금 판과 같으면 최신이다")
    func upToDate() async {
        let updater = updater(.standalone, tag: "v\(LazyMemo.version)")
        await updater.check()
        #expect(updater.state == .upToDate)
        #expect(updater.lastChecked != nil)
    }

    @Test("확인이 실패해도 조용히 «최신입니다» 가 되지 않는다")
    func failureIsVisible() async {
        struct Offline: Error {}
        let updater = Updater(settings: settings(), source: .standalone, fetch: { _ in throw Offline() })
        await updater.check()
        if case .failed = updater.state {} else {
            Issue.record("실패가 상태에 남지 않았다: \(updater.state)")
        }
    }

    @Test("swift run 으로 도는 중에는 묻지도 않는다 — 바꿀 번들이 없다")
    func silentInDevelopment() async {
        let updater = updater(.development)
        #expect(!updater.isEnabled)
        await updater.check(userAsked: true)
        #expect(updater.state == .idle)
    }

    @Test("꺼 두면 스스로 묻지 않지만, 사람이 직접 누르면 이번 한 번은 묻는다")
    func respectsSettingButObeysUser() async {
        let store = settings()
        let updater = updater(.standalone, settings: store)
        updater.setEnabled(false)

        #expect(store.current.checksForUpdates == false)
        await updater.check()
        #expect(updater.state == .idle)

        await updater.check(userAsked: true)
        #expect(updater.state != .idle)
    }

    @Test("Homebrew 로 깔린 앱은 스스로 바꾸지 않고 그렇게 말한다")
    func refusesToReplaceHomebrewInstall() async {
        let updater = updater(.homebrew)
        await updater.check(userAsked: true)
        await updater.install()

        guard case .failed(let reason) = updater.state else {
            Issue.record("brew 설치를 그냥 바꾸려 했다: \(updater.state)")
            return
        }
        #expect(reason.contains("brew upgrade --cask lazymemo"))
    }
}
