import Foundation

/// 사람에게 보이는 말은 이 문을 지난다.
///
/// **한국어 원문이 열쇠다.** 코드에는 한국어를 그대로 적고, 다른 말은
/// `Resources/<lang>.lproj/Localizable.strings` 표가 안다. 표에 없는 말은 원문
/// 그대로 나오므로 한 줄 빠뜨려도 한국어 사용자는 아무것도 잃지 않고, 영어
/// 사용자에게는 한국어 한 줄이 보여서 빠진 자리가 곧바로 드러난다.
///
/// `ko.lproj` 는 그래서 거의 비어 있다. 적는 것은 한 가지뿐 — 같은 한국어가 두
/// 뜻으로 갈려 영어가 달라지는 자리(「3일 전」이 *ago* 이기도 *before* 이기도
/// 할 때). 그때 열쇠를 달리 두고 ko 표가 같은 한국어로 되돌린다.
///
/// 표를 고르는 기준은 `Words.locale` — `Locale.current` 의 이름, 곧 앱이 실제로
/// 서 있는 말이고 SwiftUI 의 `Text("…")` 가 보는 것과 같은 답이다 (개발 언어가
/// 영어라 지원하지 않는 말의 사용자는 양쪽 다 영어로 떨어진다). `locale` 을 손으로
/// 주는 것은 시험뿐이다 — 기계의 말과 상관없이 같은 답을 받으려고.
///
/// 보간은 `String.LocalizationValue` 의 규칙을 따른다: 정수는 `%lld`, 글은 `%@`.
/// 표의 열쇠도 그 모양으로 적는다 — `"메모 %lld장"`.
func L(_ key: String.LocalizationValue, locale: Locale = Words.locale) -> String {
    let resource = LocalizedStringResource(key, locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    return String(localized: resource)
}

/// 사람에게 보이는 말과 날짜가 따르는 로케일 — **늘 이름이 있는 로케일**이다.
///
/// `Locale.current` 의 이름을 그대로 쓴다. 앱 번들 안에서 그것은 번들이 고른 말에
/// 사용자의 지역을 더한 것(ko 기계 「ko_KR」, 영어로 켠 앱 「en_KR」)이라 뜻은 같지만,
/// `.current` 그 값을 `LocalizedStringResource` 에 주는 것과는 두 가지가 다르다.
///
/// - `.current` 는 「주 번들이 고른 말」을 뜻해서, lproj 가 없는 실행 파일(`swift run`·
///   `swift test` 의 툴체인 헬퍼·`.build` 의 MCP)에서는 고를 것이 없어 늘 개발 언어(영어)로
///   떨어진다 — 기계가 한국어여도. 이름을 주면 그 표를 찾으므로 한국어 기계에서 한국어가 뜬다.
/// - `.current` 는 ko 표에 없는 열쇠를 **영어 stringsdict 로 건너뛴다.** 복수형 열쇠(「사진 %lld장」)
///   는 영어 표에만 있고, 한국어에는 단·복수가 없어 「other」 꼴을 고르므로 한국어 앱에
///   「1 photos」가 섰다 (2026-09-15 에 실제로 폰에서 봤다). 이름을 주면 그 표만 본다.
///
/// `LAZYMEMO_LANGUAGE=ko` 가 있으면 그 말이다 — 시험이 기계와 상관없이 같은 답을 받는
/// 길(`scripts/test.sh`). 앱 번들은 이 변수를 받을 일이 없다.
public enum Words {
    public static let locale: Locale = {
        if let forced = ProcessInfo.processInfo.environment["LAZYMEMO_LANGUAGE"], !forced.isEmpty {
            return Locale(identifier: forced)
        }
        return Locale(identifier: Locale.current.identifier)
    }()
}

/// 날짜를 그 말의 어순으로 적는다.
///
/// 「9월 14일」을 손으로 이어 붙이면 영어에서 「9month 14day」가 된다. 어느 말이든
/// `Date.FormatStyle` 이 그 말의 순서와 이름을 안다 — ko 「9월 14일」, en 「Sep 14」.
/// 시험이 `locale` 을 주면 기계의 말과 상관없이 같은 답을 낸다.
public enum DateWords {
    /// 「9월 14일」 · 「Sep 14」.
    public static func monthDay(
        _ day: CalendarDate, calendar: Calendar = .current, locale: Locale = Words.locale
    ) -> String {
        format(day, calendar: calendar, locale: locale) { $0.month(.abbreviated).day() }
    }

    /// 「9월 14일 (월)」 · 「Mon, Sep 14」. 칩과 머리글처럼 조금 더 긴 자리.
    public static func monthDayWeekday(
        _ day: CalendarDate, calendar: Calendar = .current, locale: Locale = Words.locale
    ) -> String {
        format(day, calendar: calendar, locale: locale) { $0.month(.abbreviated).day().weekday(.abbreviated) }
    }

    /// 「14일 월요일」 · 「14 Monday」. 달 격자의 칸을 소리로 읽을 때.
    public static func dayWeekday(
        _ day: CalendarDate, calendar: Calendar = .current, locale: Locale = Words.locale
    ) -> String {
        format(day, calendar: calendar, locale: locale) { $0.day().weekday(.wide) }
    }

    /// 「2026년 9월」 · 「September 2026」.
    public static func yearMonth(
        year: Int, month: Int, calendar: Calendar = .current, locale: Locale = Words.locale
    ) -> String {
        format(CalendarDate(year: year, month: month, day: 1), calendar: calendar, locale: locale) {
            $0.year().month(.wide)
        }
    }

    /// 「9월」 · 「September」. 달력의 머리글.
    public static func month(
        _ month: Int, calendar: Calendar = .current, locale: Locale = Words.locale
    ) -> String {
        format(CalendarDate(year: 2000, month: month, day: 1), calendar: calendar, locale: locale) {
            $0.month(.wide)
        }
    }

    /// 요일 머리글 한 글자씩, 일요일부터. ko 「일 월 화 …」, en 「S M T …」.
    public static func weekdayLetters(calendar: Calendar = .current, locale: Locale = Words.locale) -> [String] {
        var calendar = calendar
        calendar.locale = locale
        return calendar.veryShortWeekdaySymbols
    }

    private static func format(
        _ day: CalendarDate, calendar: Calendar, locale: Locale,
        _ fields: (Date.FormatStyle) -> Date.FormatStyle
    ) -> String {
        guard let date = day.startOfDay(calendar: calendar) else { return day.description }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(fields(style))
    }
}
