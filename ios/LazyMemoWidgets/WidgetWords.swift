import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore

/// 위젯의 말 — 폰의 「지금」 띠(`NowBand.reasonText`)와 같은 문장.
///
/// 한국어 원문이 열쇠이고 영어는 `en.lproj/Localizable.strings` 가 안다 (`Sources/LazyMemoCore/Words.swift`).
enum WidgetWords {
    /// 「다시 보기 · 오후 3:00」 · 「오늘 일정 · 오후 3:00 지남」 · 「오늘 일정」 · 「고정」.
    static func reason(_ card: Recall.Card, now: Date) -> String {
        let time = card.moment.map(time)
        let passed = card.moment.map { $0 <= now } ?? false
        switch (card.reason, time, passed) {
        case (.revisit, let time?, false): return String(localized: "다시 보기 · \(time)")
        case (.revisit, let time?, true): return String(localized: "다시 보기 · \(time) 지남")
        case (.revisit, nil, _): return String(localized: "다시 보기")
        case (.today, let time?, false): return String(localized: "오늘 일정 · \(time)")
        case (.today, let time?, true): return String(localized: "오늘 일정 · \(time) 지남")
        case (.today, nil, _): return String(localized: "오늘 일정")
        case (.pinned, _, _): return String(localized: "고정")
        }
    }

    /// 잠금 화면처럼 좁은 자리의 이유 — 시각만, 없으면 이유의 낱말.
    static func shortReason(_ card: Recall.Card) -> String {
        if let moment = card.moment { return time(moment) }
        switch card.reason {
        case .revisit: return String(localized: "다시 보기")
        case .today: return String(localized: "오늘 일정")
        case .pinned: return String(localized: "고정")
        }
    }

    static func symbol(_ reason: Recall.Reason) -> String {
        switch reason {
        case .revisit: "bell.fill"
        case .today: "calendar"
        case .pinned: "pin.fill"
        }
    }

    /// 「오후 3:00」 — 띠와 같은 꼴.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 「오늘」·「내일」·「9월 18일 (목)」.
    static func day(_ day: CalendarDate, now: Date, calendar: Calendar = .current) -> String {
        let today = CalendarDate(now, calendar: calendar)
        if day == today { return String(localized: "오늘") }
        if let next = calendar.date(byAdding: .day, value: 1, to: now), day == CalendarDate(next, calendar: calendar) {
            return String(localized: "내일")
        }
        return DateWords.monthDayWeekday(day, calendar: calendar)
    }

    /// 고정 칸의 날 — 「오늘」·「내일」·「20일」. 칸이 좁아 **달은 넘어갈 때만** 적는다
    /// (그 위에 달 격자나 오늘 날짜가 늘 서 있어 어느 달인지는 이미 보인다).
    static func columnDay(_ day: CalendarDate, now: Date, calendar: Calendar = .current) -> String {
        let today = CalendarDate(now, calendar: calendar)
        if day == today { return String(localized: "오늘") }
        if let next = calendar.date(byAdding: .day, value: 1, to: now), day == CalendarDate(next, calendar: calendar) {
            return String(localized: "내일")
        }
        if day.year == today.year, day.month == today.month { return String(localized: "\(day.day)일") }
        return "\(day.month).\(day.day)"
    }

    /// 머리 오른쪽의 오늘 — 「9월 18일 (목)」. 카드가 **오늘의 것**임을 한 줄이 말한다.
    static func headDay(_ now: Date, calendar: Calendar = .current) -> String {
        DateWords.monthDayWeekday(CalendarDate(now, calendar: calendar), calendar: calendar)
    }

    /// 「18:12 출발 · 2호선」 — 알림의 둘째 줄과 같은 시계(`RouteNote.clock`).
    static func departure(_ departure: WidgetAgenda.Departure, calendar: Calendar = .current) -> String {
        let clock = RouteNote.clock(departure.at, calendar: calendar)
        guard let ride = departure.ride else { return String(localized: "\(clock) 출발") }
        return String(localized: "\(clock) 출발 · \(ride)")
    }
}
