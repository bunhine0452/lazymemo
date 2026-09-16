import Foundation
import Testing
@testable import LazyMemoCore

@Suite("RouteNote — 가는 길을 마크다운으로 적고 도로 읽는다")
struct RouteNoteTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    private var arrive: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 18, minute: 30))!
    }

    private var sample: TransitRoute {
        TransitRoute(origin: "석촌고분역", destination: "투파인드피터 잠실점", minutes: 21, arrive: arrive, fare: 1500, legs: [
            .init(mode: .walk, minutes: 2),
            .init(mode: .bus, minutes: 8, line: "3314", kind: "지선", from: "잠실여고후문", to: "잠실역.롯데월드", stops: 4),
            .init(mode: .subway, minutes: 6, line: "2호선", from: "잠실", to: "잠실새내", stops: 1, heading: "강남 방면", exit: "2"),
            .init(mode: .walk, minutes: 4),
        ])
    }

    @Test("절의 모양 — 사람이 읽는 줄 그대로")
    func renders() {
        let text = RouteNote.render(sample, calendar: calendar)
        #expect(text == """
        ## 가는 길
        석촌고분역 → 투파인드피터 잠실점 · 21분 · 18:09 출발 · 18:30 도착 · 1,500원 · 환승 1회
        - 걷기 2분
        - 버스 3314 (지선) 잠실여고후문 → 잠실역.롯데월드 · 8분 · 4정류장
        - 지하철 2호선 잠실 → 잠실새내 · 6분 · 1정거장 · 강남 방면 · 2번 출구로
        - 걷기 4분
        """)
    }

    @Test("적은 것을 도로 읽으면 같다")
    func roundTrips() {
        let body = RouteNote.append(sample, to: "수요일 밥약속\nhttps://naver.me/GFB1MHiW", calendar: calendar)
        let read = RouteNote.read(body, day: arrive, calendar: calendar)
        #expect(read == sample)
        #expect(read?.depart == arrive.addingTimeInterval(-21 * 60))
        #expect(read?.kind == .mixed)
        #expect(read?.transfers == 1)
        #expect(read?.transferWords == "버스 → 지하철")
    }

    @Test("이미 있으면 갈아 끼운다 — 한 메모에 길은 하나")
    func replaces() {
        let once = RouteNote.append(sample, to: "밥약속", calendar: calendar)
        var taxi = sample
        taxi.legs = [.init(mode: .taxi, minutes: 15, fare: 9000, distance: 6200)]
        taxi.minutes = 15
        taxi.fare = nil
        let twice = RouteNote.append(taxi, to: once, calendar: calendar)
        #expect(twice.components(separatedBy: RouteNote.heading).count == 2)
        #expect(twice.hasPrefix("밥약속\n\n## 가는 길\n"))
        let read = RouteNote.read(twice, day: arrive, calendar: calendar)
        #expect(read?.kind == .taxi)
        #expect(read?.legs.first?.fare == 9000)
        #expect(read?.legs.first?.distance == 6200)
    }

    @Test("절을 떼면 본문이 원래대로 — 끝에 빈 줄을 남기지 않는다")
    func removes() {
        let body = RouteNote.append(sample, to: "밥약속\n둘째 줄", calendar: calendar)
        #expect(RouteNote.remove(from: body) == "밥약속\n둘째 줄")
        #expect(RouteNote.remove(from: "그냥 글") == "그냥 글")
        // 절 뒤에 글이 더 있어도 그 글은 그대로 남는다.
        let middle = "앞\n\n## 가는 길\n집 → 회사 · 10분 · 08:50 출발 · 09:00 도착\n- 걷기 10분\n\n뒤"
        #expect(RouteNote.remove(from: middle) == "앞\n\n뒤")
    }

    @Test("모양이 어긋나면 카드를 세우지 않는다 — 글은 그대로")
    func tolerates() {
        #expect(RouteNote.read("## 가는 길\n요약 줄이 이상함", day: arrive, calendar: calendar) == nil)
        #expect(RouteNote.read("## 가는 길\n집 → 회사 · 10분 · 09:00 도착\n- 이상한 줄", day: arrive, calendar: calendar) == nil)
        #expect(RouteNote.read("가는 길이라는 말만 있음", day: arrive, calendar: calendar) == nil)
        // 사람이 고쳐 「## 가는 길」이 문장 가운데 들어간 것은 절이 아니다.
        #expect(RouteNote.contains("오늘 ## 가는 길 이야기") == false)
    }

    @Test("애플 지도만 아는 길 — 구간 없이 대중교통 N분")
    func transitOnly() {
        let route = TransitRoute(origin: "집", destination: "회사", minutes: 25, arrive: arrive, legs: [.init(mode: .transit, minutes: 25)])
        let body = RouteNote.append(route, to: "", calendar: calendar)
        #expect(body.contains("- 대중교통 25분 · 자세한 길은 지도 앱에서"))
        let read = RouteNote.read(body, day: arrive, calendar: calendar)
        #expect(read?.kind == .transit)
        #expect(read?.fare == nil)
    }

    @Test("탈것의 색 — 아는 노선은 그 색, 모르면 회색")
    func palette() {
        #expect(TransitPalette.subwayHex(line: "2호선") == "#00A84D")
        #expect(TransitPalette.subwayHex(line: "수도권 신분당선") == "#D4003B")
        #expect(TransitPalette.subwayHex(line: "모르는선") == "#8E8E93")
        #expect(TransitPalette.busHex(kind: "간선") == "#3D5BAB")
        #expect(TransitPalette.busHex(kind: nil) == "#53B332")
    }
}
