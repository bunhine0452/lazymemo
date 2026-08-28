import CoreGraphics
import Foundation
import Testing
@testable import LazyMemoCore

@Suite("FrameClamping")
struct FrameClampingTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("화면 안의 창은 그대로 둔다")
    func leavesOnScreenFramesAlone() {
        let frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        #expect(FrameClamping.clamp(frame, into: screen) == frame)
    }

    @Test("사라진 외부 모니터의 좌표를 화면 안으로 끌어온다")
    func pullsBackFramesFromDisconnectedDisplay() {
        // 오른쪽 외부 모니터에 있던 창 (x = 2000)
        let orphan = CGRect(x: 2000, y: 300, width: 300, height: 200)
        let clamped = FrameClamping.clamp(orphan, into: screen)

        #expect(clamped.maxX <= screen.maxX)
        #expect(FrameClamping.isReachable(clamped, on: [screen]))
    }

    @Test("음수 좌표도 끌어온다")
    func pullsBackNegativeOrigins() {
        let orphan = CGRect(x: -1500, y: -400, width: 300, height: 200)
        let clamped = FrameClamping.clamp(orphan, into: screen)
        #expect(FrameClamping.isReachable(clamped, on: [screen]))
    }

    @Test("화면보다 큰 창은 화면에 맞춰 줄인다")
    func shrinksOversizedFrames() {
        let huge = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let clamped = FrameClamping.clamp(huge, into: screen)
        #expect(clamped.width == screen.width)
        #expect(clamped.height == screen.height)
    }

    @Test("일부러 걸쳐 놓은 창은 복원 때 건드리지 않는다")
    func leavesDeliberatelyOverhangingWindows() {
        let overhanging = CGRect(x: 1300, y: 400, width: 300, height: 200)
        let restored = FrameClamping.restore(overhanging, onto: [screen], fallback: screen)
        #expect(restored == overhanging)
    }

    @Test("모니터를 뽑으면 주 화면으로 데려온다")
    func bringsHomeWhenDisplayDisappears() {
        let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let onExternal = CGRect(x: 2000, y: 300, width: 300, height: 200)

        // 외부 모니터가 연결된 동안에는 그대로
        #expect(FrameClamping.restore(onExternal, onto: [screen, external], fallback: screen) == onExternal)

        // 뽑으면 주 화면 안으로
        let afterUnplug = FrameClamping.restore(onExternal, onto: [screen], fallback: screen)
        #expect(FrameClamping.isReachable(afterUnplug, on: [screen]))
        #expect(afterUnplug.maxX <= screen.maxX)
    }

    @Test("두 화면 중 하나에만 걸쳐 있어도 도달 가능하다")
    func reachableOnAnyConnectedScreen() {
        let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let onExternal = CGRect(x: 1600, y: 200, width: 300, height: 200)
        #expect(FrameClamping.isReachable(onExternal, on: [screen, external]))
        #expect(!FrameClamping.isReachable(onExternal, on: [screen]))
    }
}

@MainActor
@Suite("LayoutStore")
struct LayoutStoreTests {
    private func makeStore() -> (LayoutStore, URL) {
        let location = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-layout-\(UUID().uuidString).json", directoryHint: .notDirectory)
        return (LayoutStore(location: location), location)
    }

    @Test("저장한 좌표를 다음 기동에서 되읽는다")
    func persistsAcrossLaunches() throws {
        let (store, location) = makeStore()
        defer { try? FileManager.default.removeItem(at: location) }

        let id = ULID()
        store.set(WindowLayout(frame: CGRect(x: 10, y: 20, width: 300, height: 240), displayUUID: "SCREEN-1"), for: id)
        store.flush()

        let reopened = LayoutStore(location: location)
        #expect(reopened.layout(for: id)?.frame == CGRect(x: 10, y: 20, width: 300, height: 240))
        #expect(reopened.layout(for: id)?.displayUUID == "SCREEN-1")
    }

    @Test("창을 닫으면 숨김으로 남는다 — 삭제가 아니다")
    func hidingIsNotDeleting() {
        let (store, location) = makeStore()
        defer { try? FileManager.default.removeItem(at: location) }

        let id = ULID()
        store.set(WindowLayout(frame: .zero), for: id)
        store.setHidden(true, for: id)

        #expect(store.layout(for: id)?.hidden == true)
        #expect(store.layout(for: id) != nil)
    }

    @Test("사라진 메모의 좌표는 정리한다")
    func prunesOrphanedLayouts() {
        let (store, location) = makeStore()
        defer { try? FileManager.default.removeItem(at: location) }

        let alive = ULID()
        let gone = ULID()
        store.set(WindowLayout(frame: .zero), for: alive)
        store.set(WindowLayout(frame: .zero), for: gone)

        store.prune(keeping: [alive])

        #expect(store.layout(for: alive) != nil)
        #expect(store.layout(for: gone) == nil)
    }

    @Test("깨진 layout.json 은 무시하고 빈 상태로 뜬다")
    func survivesCorruptFile() throws {
        let location = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-layout-\(UUID().uuidString).json", directoryHint: .notDirectory)
        defer { try? FileManager.default.removeItem(at: location) }
        try Data("{ 이건 JSON 이 아니다".utf8).write(to: location)

        let store = LayoutStore(location: location)
        #expect(store.layout(for: ULID()) == nil)
    }
}
