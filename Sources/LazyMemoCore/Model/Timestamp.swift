import Foundation

/// frontmatter 의 시각 표기 (`2026-08-28T16:29:50+09:00`).
///
/// 오프셋을 `Z` 로 정규화하지 않고 로컬 오프셋 그대로 쓴다 — 사용자가 파일을
/// 직접 열어 볼 것을 전제로 하기 때문이다 (D4). 읽을 때는 `Z` 도 받아들인다.
public extension Date {
    /// 초 미만을 버린다.
    ///
    /// 정본인 마크다운은 초 단위까지만 적는다(사람이 읽을 파일이라 그렇다).
    /// 모델이 그보다 정밀한 값을 들고 있으면 파일에 썼다 읽는 순간 값이
    /// 달라져, 메모리와 디스크가 미묘하게 어긋난다.
    var truncatingSubsecond: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down))
    }
}

public enum Timestamp {
    private static func style(_ timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(
            dateSeparator: .dash,
            dateTimeSeparator: .standard,
            timeSeparator: .colon,
            timeZoneSeparator: .colon,
            includingFractionalSeconds: false,
            timeZone: timeZone
        )
    }

    public static func string(from date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(style(timeZone))
    }

    /// `+09:00` · `+0900` · `Z` 를 모두 받는다. 남이 쓴 파일도 열려야 한다.
    public static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
