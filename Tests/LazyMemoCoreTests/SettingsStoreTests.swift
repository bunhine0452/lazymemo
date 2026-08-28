import Foundation
import Testing
@testable import LazyMemoCore

/// 설정은 파생물과 성격이 다르다 — 지우면 사용자가 정한 것이 사라진다.
@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeLocation() -> URL {
        let directory = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-settings-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "settings.json", directoryHint: .notDirectory)
    }

    @Test("파일이 없으면 빈 설정으로 시작한다 — 기본값은 앱이 정한다")
    func startsEmpty() {
        let store = SettingsStore(location: makeLocation())
        #expect(store.current == .default)
        #expect(store.current.hotkeyKeyCode == nil)
        #expect(store.current.embedsLinks == nil)
    }

    @Test("바꾼 값은 즉시 파일에 남고 다음 기동에서 되읽힌다")
    func persistsAcrossLaunches() {
        let location = makeLocation()
        SettingsStore(location: location).update {
            $0.hotkeyKeyCode = 49
            $0.hotkeyModifiers = 2304
            $0.embedsLinks = false
        }

        let reopened = SettingsStore(location: location)
        #expect(reopened.current.hotkeyKeyCode == 49)
        #expect(reopened.current.hotkeyModifiers == 2304)
        #expect(reopened.current.embedsLinks == false)
    }

    @Test("깨진 파일 때문에 앱이 못 뜨지 않는다 — 빈 설정으로 시작한다")
    func survivesCorruptFile() throws {
        let location = makeLocation()
        try Data("{ 이건 JSON 이 아니다".utf8).write(to: location)

        let store = SettingsStore(location: location)
        #expect(store.current == .default)

        // 그리고 다시 쓸 수 있어야 한다 — 깨진 파일에 갇히면 안 된다.
        store.update { $0.embedsLinks = true }
        #expect(SettingsStore(location: location).current.embedsLinks == true)
    }

    @Test("사용자가 정하지 않은 값은 파일에 남기지 않는다")
    func writesOnlyWhatWasSet() throws {
        let location = makeLocation()
        SettingsStore(location: location).update { $0.embedsLinks = false }

        let text = try String(contentsOf: location, encoding: .utf8)
        #expect(text.contains("embedsLinks"))
        #expect(!text.contains("hotkeyKeyCode"))
    }
}
