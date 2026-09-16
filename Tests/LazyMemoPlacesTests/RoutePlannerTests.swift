import Foundation
import Testing
import LazyMemoCore
@testable import LazyMemoPlaces

@MainActor
@Suite("RoutePlanner — 출발지 되묻기 → 길 찾기 → 탈것 고르기 → 메모에 적기")
struct RoutePlannerTests {
    private let seoul = Coordinate(latitude: 37.5107, longitude: 127.0852)!
    private let sokchon = Coordinate(latitude: 37.5023, longitude: 127.1104)!

    private func makeStore() throws -> (MemoStore, AppPaths) {
        let root = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-route-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = AppPaths(vault: root.appending(path: "vault", directoryHint: .isDirectory),
                             support: root.appending(path: "support", directoryHint: .isDirectory))
        try paths.createDirectories()
        return (try MemoStore(paths: paths), paths)
    }

    private func cleanUp(_ paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.vault.deletingLastPathComponent())
    }

    private var now: Date { Date(timeIntervalSince1970: 1_789_000_000) }
    private var appointment: Date { now.addingTimeInterval(6 * 3600) }

    private func routes(arrive: Date) -> [TransitRoute] {
        [
            TransitRoute(origin: "스타벅스 송파사거리점", destination: "투파인드피터 잠실점", minutes: 21, arrive: arrive, fare: 1500, legs: [
                .init(mode: .walk, minutes: 2),
                .init(mode: .bus, minutes: 8, line: "3314", kind: "지선", from: "잠실여고후문", to: "잠실역.롯데월드", stops: 4),
                .init(mode: .bus, minutes: 6, line: "4318", kind: "간선", from: "잠실역.롯데월드", to: "잠실새내역2번출구", stops: 2),
                .init(mode: .walk, minutes: 4),
            ]),
            TransitRoute(origin: "스타벅스 송파사거리점", destination: "투파인드피터 잠실점", minutes: 19, arrive: arrive, fare: 1650, legs: [
                .init(mode: .walk, minutes: 3),
                .init(mode: .subway, minutes: 6, line: "2호선", from: "잠실", to: "강남", stops: 3, heading: "강남 방면"),
                .init(mode: .bus, minutes: 7, line: "146", kind: "간선", from: "강남역", to: "논현역", stops: 3),
            ]),
            TransitRoute(origin: "스타벅스 송파사거리점", destination: "투파인드피터 잠실점", minutes: 12, arrive: arrive, legs: [
                .init(mode: .taxi, minutes: 12, fare: 9800, distance: 6200),
            ]),
        ]
    }

    /// 접속 없는 가짜 — 링크는 잠실의 자리로, 이름은 석촌의 자리로.
    private func services(routes: [TransitRoute], locateFails: Bool = false) -> RoutePlanner.Services {
        let seoul = self.seoul, sokchon = self.sokchon
        return RoutePlanner.Services(
            locate: { text, _ in
                if locateFails { return nil }
                if text.hasPrefix("https://naver.me/") { return LocatedPlace(name: "투파인드피터 잠실점", geo: seoul) }
                return LocatedPlace(name: text, geo: sokchon)
            },
            find: { _, _, _ in routes }
        )
    }

    private func planner(_ store: MemoStore, routes: [TransitRoute], asks: Bool = true, locateFails: Bool = false) -> RoutePlanner {
        let planner = RoutePlanner(store: store, settings: { Settings(asksRoutes: asks) },
                                   services: services(routes: routes, locateFails: locateFails))
        planner.now = { [now] in now }
        return planner
    }

    /// 비동기 일이 자리를 잡을 때까지 — 최대 2초.
    private func settle(_ planner: RoutePlanner, until condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test("링크로 적은 약속 — 출발지를 묻고, 탈것을 묻고, 고르면 메모에 길과 출발 알림이 선다")
    func fullConversation() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "https://naver.me/GFB1MHiW 밥약속", at: appointment)
        let planner = planner(store, routes: routes(arrive: appointment))
        var written: (Memo, TransitRoute)?
        planner.onWritten = { written = ($0, $1) }

        #expect(planner.begin(memo))
        #expect(planner.step == .askingOrigin)
        #expect(planner.question == RoutePlanner.originQuestion)
        #expect(planner.choices == [RoutePlanner.skipChoice])
        // 약속 자리는 기다리는 동안 찾아 파일에 적힌다 — 자리 카드가 선다.
        await settle(planner) { planner.summary?.contains("투파인드피터 잠실점") == true }
        #expect(store.memo(memo.id)?.place == "투파인드피터 잠실점")
        #expect(store.memo(memo.id)?.geo != nil)
        #expect(planner.summary?.contains("투파인드피터 잠실점") == true)

        #expect(planner.reply("석촌고분역에서 출발해"))
        await settle(planner) { planner.step == .choosing }
        #expect(planner.step == .choosing)
        #expect(planner.question == "경로 3개를 찾았어요 — 버스 21분 · 지하철 19분 (환승) · 택시 12분 (약 9,800원). 무엇으로 갈까요?")
        #expect(planner.choices == ["버스", "지하철", "택시", RoutePlanner.skipChoice])

        #expect(planner.reply("버스로"))
        await settle(planner) { written != nil }
        let (saved, route) = try #require(written)
        #expect(route.kind == .bus)
        #expect(saved.body.hasSuffix("- 걷기 4분"))
        #expect(saved.body.contains("- 버스 3314 (지선) 잠실여고후문 → 잠실역.롯데월드 · 8분 · 4정류장"))
        #expect(RouteNote.read(saved.body, day: appointment)?.transfers == 1)
        // 출발 10분 전에 종이가 나온다 — 알림은 그 시각에.
        #expect(saved.surface == appointment.addingTimeInterval(-(21 + 10) * 60))
        #expect(planner.step == .idle)
        #expect(planner.notice == "가는 길을 적었어요 — 버스 21분, \(RouteNote.clock(route.depart)) 출발 · 환승 1회 (버스 → 버스) · 출발 10분 전에 알려요")
        // 알림의 둘째 줄이 출발과 첫 탈것을 말한다.
        #expect(Recall.departureLine(saved) == "\(RouteNote.clock(route.depart)) 출발 — 잠실여고후문에서 3314 버스 · 21분")
    }

    @Test("지하철만으로는 못 가면 갈아타는 길을 내밀고 환승을 말한다")
    func subwayFallsBackToMixed() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: appointment, place: "투파인드피터 잠실점", geo: seoul)
        let planner = planner(store, routes: routes(arrive: appointment))
        var written: TransitRoute?
        planner.onWritten = { written = $1 }
        planner.begin(memo)
        planner.reply("석촌고분역")
        await settle(planner) { planner.step == .choosing }
        planner.choose("지하철")
        await settle(planner) { written != nil }
        #expect(written?.kind == .mixed)
        #expect(planner.notice?.contains("환승 1회 (지하철 → 버스)") == true)
    }

    @Test("「됐어」— 조용히 물러나고 메모는 그대로")
    func skips() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: appointment, place: "잠실", geo: seoul)
        let planner = planner(store, routes: routes(arrive: appointment))
        planner.begin(memo)
        #expect(planner.reply("됐어"))
        #expect(planner.step == .idle)
        #expect(planner.question == nil)
        #expect(store.memo(memo.id)?.body == "밥약속")
        #expect(store.memo(memo.id)?.surface == nil)
    }

    @Test("물을 것이 없으면 묻지 않는다 — 시각이 없거나, 자리가 없거나, 지난 약속이거나, 설정이 꺼졌거나")
    func doesNotAsk() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let planner = planner(store, routes: [])
        #expect(!planner.begin(try await store.create(body: "밥약속", place: "잠실")))
        #expect(!planner.begin(try await store.create(body: "밥약속", at: appointment)))
        #expect(!planner.begin(try await store.create(body: "밥약속", at: now.addingTimeInterval(-60), place: "잠실")))
        let off = self.planner(store, routes: [], asks: false)
        #expect(!off.begin(try await store.create(body: "밥약속", at: appointment, place: "잠실")))
        #expect(RoutePlanner.applies(body: "https://naver.me/x 밥", at: appointment, place: nil, geo: nil, now: now))
        #expect(!RoutePlanner.applies(body: "https://youtube.com/x 밥", at: appointment, place: nil, geo: nil, now: now))
    }

    @Test("출발지를 못 찾으면 같은 질문을 다시 세운다")
    func originNotFound() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: appointment, place: "잠실", geo: seoul)
        let planner = planner(store, routes: routes(arrive: appointment), locateFails: true)
        planner.begin(memo)
        planner.reply("어딘지모를곳")
        await settle(planner) { planner.trouble != nil }
        #expect(planner.step == .askingOrigin)
        #expect(planner.trouble == "「어딘지모를곳」를 지도에서 못 찾았어요 — 다른 이름이나 지도 링크로 말해 주세요")
    }

    @Test("대중교통을 못 쟀으면 택시만 — 문구가 그 사실을 말한다")
    func taxiOnly() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: appointment, place: "잠실", geo: seoul)
        let apple = [
            TransitRoute(origin: "a", destination: "b", minutes: 12, arrive: appointment, legs: [.init(mode: .taxi, minutes: 12, fare: 9800, distance: 6000)]),
        ]
        let planner = planner(store, routes: apple)
        planner.begin(memo)
        planner.reply("석촌고분역")
        await settle(planner) { planner.step == .choosing }
        #expect(planner.question == "대중교통 길은 지금 못 찾았어요 — 택시 12분 (약 9,800원). 무엇으로 갈까요?")
        #expect(planner.choices == ["택시", RoutePlanner.skipChoice])
        planner.reply("택시")
        await settle(planner) { planner.step == .idle && planner.notice != nil }
        #expect(store.memo(memo.id)?.body.contains("- 택시 12분 · 약 9,800원 · 6.0km") == true)
    }

    @Test("시간표를 아는 길은 고른 뒤 약속에 맞춰 되재어 적는다")
    func refinesBeforeWriting() async throws {
        let (store, paths) = try makeStore()
        defer { cleanUp(paths) }
        let memo = try await store.create(body: "밥약속", at: appointment, place: "잠실", geo: seoul)
        var naver = routes(arrive: appointment.addingTimeInterval(-30 * 60))
        for index in naver.indices { naver[index].provider = "naver" }
        let refined = TransitRoute(origin: "석촌고분역", destination: "투파인드피터 잠실점", minutes: 22, arrive: appointment.addingTimeInterval(-3 * 60), fare: 1500,
                                   legs: [.init(mode: .bus, minutes: 22, line: "3317", kind: "지선", from: "석촌역", to: "잠실새내역", stops: 4, boardAt: appointment.addingTimeInterval(-20 * 60))],
                                   provider: "naver")
        var services = services(routes: naver)
        services.refine = { chosen, _, _, _ in chosen.kind == .bus ? refined : nil }
        let planner = RoutePlanner(store: store, settings: { Settings() }, services: services)
        planner.now = { [now] in now }
        var written: TransitRoute?
        planner.onWritten = { written = $1 }
        planner.begin(memo)
        planner.reply("석촌고분역")
        await settle(planner) { planner.step == .choosing }
        planner.choose("버스")
        await settle(planner) { written != nil }
        #expect(written == refined)
        let saved = try #require(store.memo(memo.id))
        #expect(saved.body.contains("· \(RouteNote.clock(refined.legs[0].boardAt!)) 승차"))
        #expect(saved.surface == refined.depart.addingTimeInterval(-RoutePlanner.lead))
    }

    @Test("탈것의 말 — 「버스랑 지하철」은 갈아타는 길, 「빠른 걸로」는 가장 빠른 것")
    func modeWords() {
        let list = routes(arrive: appointment)
        #expect(RoutePlanner.kind(in: "버스", among: list) == .bus)
        #expect(RoutePlanner.kind(in: "전철로 갈래", among: list) == .subway)
        #expect(RoutePlanner.kind(in: "버스랑 지하철", among: list) == .mixed)
        #expect(RoutePlanner.kind(in: "택시 타고", among: list) == .taxi)
        #expect(RoutePlanner.kind(in: "제일 빠른 걸로", among: list) == .taxi)
        #expect(RoutePlanner.kind(in: "글쎄", among: list) == nil)
        #expect(RoutePlanner.isSkip("몰라"))
        #expect(!RoutePlanner.isSkip("석촌고분역 근처 아니고 잠실역에서 출발할게 몰라도 돼"))
    }
}
