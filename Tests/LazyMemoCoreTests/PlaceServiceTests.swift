import Foundation
import Testing
@testable import LazyMemoCore

@Suite("MemoService — 장소")
struct PlaceServiceTests {
    private func makeService() throws -> (MemoService, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-place-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(
            vault: root.appending(path: "vault", directoryHint: .isDirectory),
            support: root.appending(path: "support", directoryHint: .isDirectory)
        )
        try paths.createDirectories()
        return (try MemoService(paths: paths), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    @Test("장소를 붙여 만들면 파일에 남는다")
    func createsWithPlace() async throws {
        let (service, paths) = try makeService()
        defer { cleanUp(paths) }

        let memo = try await service.create(
            body: "치과", place: "강남역 3번 출구", geo: Coordinate("37.4979,127.0276")
        )
        let onDisk = try await MemoVault(paths: paths).load(memo.id)
        #expect(onDisk.place == "강남역 3번 출구")
        #expect(onDisk.geo == Coordinate("37.4979,127.0276"))
    }

    @Test("장소를 넘기지 않은 update 는 장소를 지우지 않는다")
    func preservesPlaceOnUnrelatedUpdate() async throws {
        let (service, paths) = try makeService()
        defer { cleanUp(paths) }

        let memo = try await service.create(body: "치과", place: "강남역")
        let updated = try await service.update(memo.id, body: "치과 예약")
        #expect(updated.place == "강남역")
    }

    @Test("빈 문자열을 넘기면 장소를 뗀다 — 날짜와 같은 계약이다 (§9.2)")
    func clearsPlace() async throws {
        let (service, paths) = try makeService()
        defer { cleanUp(paths) }

        let memo = try await service.create(
            body: "치과", place: "강남역", geo: Coordinate("37.4979,127.0276")
        )
        let cleared = try await service.update(memo.id, place: .some(nil), geo: .some(nil))
        #expect(cleared.place == nil)
        #expect(cleared.geo == nil)
        #expect(!cleared.hasPlace)
    }

    @Test("장소만 바꿔도 날짜는 그대로다 — 두 축은 서로를 건드리지 않는다")
    func placeAndTimeAreIndependent() async throws {
        let (service, paths) = try makeService()
        defer { cleanUp(paths) }

        let memo = try await service.create(
            body: "치과", due: CalendarDate(year: 2026, month: 9, day: 1), place: "강남역"
        )
        let moved = try await service.update(memo.id, place: .some("광화문"))
        #expect(moved.place == "광화문")
        #expect(moved.due == CalendarDate(year: 2026, month: 9, day: 1))
    }
}
