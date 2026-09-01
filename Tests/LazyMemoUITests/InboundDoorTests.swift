import AppKit
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

@MainActor
@Suite("InboundDoor — 밖에서 들어오는 문")
struct InboundDoorTests {
    private func makeDoor() throws -> (store: MemoStore, door: InboundDoor) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-door-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()

        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: LayoutStore(location: paths.layout),
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        return (store, InboundDoor(store: store, windows: windows))
    }

    @Test("URL 로 들어온 글이 종이가 된다")
    func urlBecomesMemo() async throws {
        let (_, door) = try makeDoor()
        let url = URL(string: "lazymemo://add?text=%EC%9E%A5%EB%B3%B4%EA%B8%B0")!
        let memo = await door.receive(url: url)
        #expect(memo?.body == "장보기")
    }

    @Test("문으로 들어와도 날짜와 장소를 읽는다 — 문마다 다르게 읽지 않는다")
    func readsDateAndPlaceAtTheDoor() async throws {
        let (_, door) = try makeDoor()
        let memo = await door.receive(text: "내일 치과 @강남역")
        #expect(memo?.place == "강남역")
        #expect(memo?.due != nil)
        #expect(memo?.body == "치과")
    }

    @Test("복사해 온 주소는 그대로 장소가 된다 — 클립보드도 같은 문으로 들어온다")
    func clipboardAddressBecomesPlace() async throws {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-clip-place-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        let store = try MemoStore(paths: paths)
        let settings = SettingsStore(location: paths.settings)
        let windows = NoteWindowManager(
            store: store,
            layouts: LayoutStore(location: paths.layout),
            previews: LinkPreviewStore(
                cacheDirectory: paths.support.appending(path: "links", directoryHint: .isDirectory),
                settings: settings
            ),
            appearance: PaperAppearance(settings: settings)
        )
        let capture = ClipboardCapture(store: store, windows: windows)

        let board = NSPasteboard(name: NSPasteboard.Name("lazymemo-place-\(UUID().uuidString)"))
        board.clearContents()
        board.setString("서울특별시 강남구 테헤란로 152", forType: .string)

        let memo = await capture.capture(from: board)
        #expect(memo?.place == "서울특별시 강남구 테헤란로 152")
        #expect(memo?.body == "서울특별시 강남구 테헤란로 152")
    }

    @Test("받지 않는 주소는 종이를 만들지 않는다")
    func ignoresForeignURLs() async throws {
        let (store, door) = try makeDoor()
        #expect(await door.receive(url: URL(string: "https://example.com/add?text=hi")!) == nil)
        #expect(await door.receive(url: URL(string: "lazymemo://run?cmd=rm")!) == nil)
        #expect(store.memos.isEmpty)
    }
}

/// 번들 설정과 코드가 어긋나면 **메뉴에는 나타나는데 눌러도 아무 일이 없다.**
/// 화면을 봐서는 알 수 없는 종류의 고장이라 짝을 못 박는다.
@Suite("번들 설정과 코드의 짝")
struct BundleWiringTests {
    private var infoPlist: [String: Any] {
        // 시험은 번들 밖에서 도므로 저장소의 원본을 직접 읽는다.
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()   // LazyMemoUITests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 저장소 뿌리
        let url = root.appending(path: "Resources/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization
                  .propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return object
    }

    @Test("Info.plist 가 InboundLink 와 같은 스킴을 등록한다")
    func registersScheme() {
        let types = infoPlist["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(InboundLink.scheme))
    }

    @Test("NSMessage 가 실제로 있는 메서드를 가리킨다")
    func serviceMessageMatchesSelector() {
        let services = infoPlist["NSServices"] as? [[String: Any]] ?? []
        guard let message = services.first?["NSMessage"] as? String else {
            Issue.record("NSServices 에 NSMessage 가 없다")
            return
        }
        // AppKit 이 부르는 이름은 `<NSMessage>:userData:error:` 다.
        let selector = Selector("\(message):userData:error:")
        #expect(InboundDoor.instancesRespond(to: selector))
    }

    @Test("버전은 세 곳이 같은 말을 한다 — 태그를 밀 때 CI 가 세는 그 값이다")
    func versionsAgree() {
        #expect(infoPlist["CFBundleShortVersionString"] as? String == LazyMemo.version)
        #expect(SemanticVersion(LazyMemo.version) != nil)
    }
}
