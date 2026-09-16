import Foundation
import Testing
@testable import LazyMemoCore

@Suite("RouteAsk — 물을 만한 약속인가, 앱 밖에서 남긴 질문")
struct RouteAskTests {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    @Test("앞으로 올 약속에 자리가 있고 길이 아직 없어야 묻는다")
    func applies() {
        let later = now.addingTimeInterval(3600)
        #expect(RouteAsk.applies(Memo(at: later, place: "잠실", body: "밥"), now: now))
        #expect(RouteAsk.applies(Memo(at: later, body: "밥 https://naver.me/GFB1MHiW"), now: now))
        #expect(!RouteAsk.applies(Memo(at: later, body: "밥"), now: now), "자리가 없다")
        #expect(!RouteAsk.applies(Memo(due: CalendarDate(now.addingTimeInterval(86400)), place: "잠실", body: "밥"), now: now), "시각이 없다")
        #expect(!RouteAsk.applies(Memo(at: now.addingTimeInterval(-60), place: "잠실", body: "밥"), now: now), "지난 약속")
        let routed = RouteNote.append(TransitRoute(origin: "a", destination: "b", minutes: 10, arrive: later, legs: [.init(mode: .taxi, minutes: 10)]), to: "밥")
        #expect(!RouteAsk.applies(Memo(at: later, place: "잠실", body: routed), now: now), "이미 길이 있다")
    }

    @Test("표는 앱 그룹 폴더의 파일 하나 — 적고, 한 번 거두면 비고, 같은 id 는 한 번만")
    func marker() throws {
        let group = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "lazymemo-group-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: group) }

        #expect(RouteAsk.takePending(in: group).isEmpty)
        let first = ULID(), second = ULID()
        RouteAsk.remember(first, in: group)
        RouteAsk.remember(first, in: group)
        RouteAsk.remember(second, in: group)
        #expect(RouteAsk.takePending(in: group) == [first, second])
        #expect(RouteAsk.takePending(in: group).isEmpty, "거둔 뒤에는 비어 있다")
        RouteAsk.remember(first, in: nil)
        #expect(RouteAsk.takePending(in: nil).isEmpty, "그룹 폴더가 없으면 아무 일도 없다")
    }
}
