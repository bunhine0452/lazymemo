import Foundation
import Testing
@testable import LazyMemoCore

@Suite("SurfaceWords")
struct SurfaceWordsTests {
    private let event = Date(timeIntervalSince1970: 1_800_000_000)

    private func lead(minutesBefore: Double) -> String? {
        SurfaceWords.lead(surface: event.addingTimeInterval(-minutesBefore * 60), event: event)
    }

    @Test("분 단위로 말한다")
    func minutes() {
        #expect(lead(minutesBefore: 30) == "30분 전")
        #expect(lead(minutesBefore: 5) == "5분 전")
    }

    @Test("한 시간이 넘으면 시간으로, 딱 떨어지지 않으면 분도 함께")
    func hours() {
        #expect(lead(minutesBefore: 60) == "1시간 전")
        #expect(lead(minutesBefore: 120) == "2시간 전")
        #expect(lead(minutesBefore: 90) == "1시간 30분 전")
    }

    @Test("하루가 넘으면 날로 말한다")
    func days() {
        #expect(lead(minutesBefore: 60 * 24) == "1일 전")
        #expect(lead(minutesBefore: 60 * 24 * 3) == "3일 전")
    }

    @Test("일정보다 나중에 나오는 것도 말할 수 있다")
    func after() {
        #expect(SurfaceWords.lead(surface: event.addingTimeInterval(600), event: event)
            == "10분 뒤")
    }

    @Test("같은 시각이면 덧붙일 말이 없다 — 「1분 전」은 알려 주는 값이 없다")
    func sameMoment() {
        #expect(SurfaceWords.lead(surface: event, event: event) == nil)
        #expect(lead(minutesBefore: 0.5) == nil)
    }
}
