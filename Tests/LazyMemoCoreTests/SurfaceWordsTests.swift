import Foundation
import Testing
@testable import LazyMemoCore

@Suite("SurfaceWords")
struct SurfaceWordsTests {
    private let event = Date(timeIntervalSince1970: 1_800_000_000)

    private let ko = Locale(identifier: "ko_KR")
    private let en = Locale(identifier: "en_US")

    private func lead(minutesBefore: Double, locale: Locale? = nil) -> String? {
        SurfaceWords.lead(
            surface: event.addingTimeInterval(-minutesBefore * 60), event: event, locale: locale ?? ko
        )
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
        #expect(SurfaceWords.lead(surface: event.addingTimeInterval(600), event: event, locale: ko)
            == "10분 뒤")
    }

    @Test("영어는 앞뒤가 뒤집힌다 — 「전」을 꼬리로 붙이지 않고 문장째 표에서 온다")
    func english() {
        #expect(lead(minutesBefore: 30, locale: en) == "30 min ahead")
        #expect(lead(minutesBefore: 60, locale: en) == "1 hr ahead")
        #expect(lead(minutesBefore: 120, locale: en) == "2 hrs ahead")
        #expect(lead(minutesBefore: 90, locale: en) == "1 hr 30 min ahead")
        #expect(lead(minutesBefore: 60 * 24, locale: en) == "1 day ahead")
        #expect(lead(minutesBefore: 60 * 24 * 3, locale: en) == "3 days ahead")
        #expect(SurfaceWords.lead(surface: event.addingTimeInterval(600), event: event, locale: en)
            == "10 min after")
    }

    @Test("같은 시각이면 덧붙일 말이 없다 — 「1분 전」은 알려 주는 값이 없다")
    func sameMoment() {
        #expect(SurfaceWords.lead(surface: event, event: event, locale: ko) == nil)
        #expect(lead(minutesBefore: 0.5) == nil)
    }
}
