import Foundation

/// 여러 나라 말의 시간 낱말을 한곳에 모은 표.
///
/// 파서 본문이 언어를 모르게 하려고 낱말만 따로 뺐다. 새 표현을 받아들이는 일이
/// **표에 한 줄 더하는 일**이 된다.
///
/// 한국어·영어·일본어·중국어를 함께 담는다. 어느 말로 적었는지 앱에게 알려주는
/// 절차는 두지 않는다 — 설정에 "입력 언어" 항목이 생기는 순간 설계문서 §1 의
/// "아무것도 배우지 않는다" 가 깨진다. 섞어 적어도 그냥 읽힌다.
enum TimeWords {

    /// 낱말표 한 줄. 값은 표마다 다르다 (날짜 차이·요일 번호·하루 중 때).
    struct Word<Value: Sendable>: Sendable {
        let text: String
        let value: Value

        init(_ text: String, _ value: Value) {
            self.text = text
            self.value = value
        }
    }

    /// 본문에서 찾아낸 낱말 하나.
    struct Match<Value: Sendable> {
        let value: Value
        /// 본문에 실제로 적혀 있던 글자. 본문에서 덜어낼 때 이것을 쓴다.
        let text: String
        let range: Range<String.Index>
    }

    /// 하루 중 때. 숫자가 없으면 대표 시각이 되고, 숫자가 있으면 24시간제로 옮긴다.
    enum DayPart: Sendable {
        case dawn       // 새벽 · dawn · 未明 · 凌晨
        case morning    // 아침 · morning · 朝 · 早上
        case forenoon   // 오전 · a.m. · 午前 · 上午
        case midday     // 낮 · 점심 · noon · 昼 · 中午
        case afternoon  // 오후 · p.m. · 午後 · 下午
        case evening    // 저녁 · evening · 夕方 · 晚上
        case night      // 밤 · night · 夜 · 晚
        case midnight   // 자정 · midnight · 真夜中 · 午夜
    }

    // MARK: 날짜 낱말

    /// `오늘` · `tomorrow` · `明後日` · `后天` — 오늘로부터 며칠.
    static let relativeDays: [Word<Int>] = [
        // 한국어
        Word("그저께", -2), Word("엊그제", -2), Word("그제", -2),
        Word("어제", -1), Word("어저께", -1),
        Word("오늘", 0), Word("금일", 0),
        Word("내일", 1), Word("명일", 1),
        Word("내일모레", 2), Word("모레", 2), Word("글피", 3),
        // 영어
        Word("day before yesterday", -2), Word("yesterday", -1),
        Word("today", 0), Word("tonight", 0), Word("tonite", 0),
        Word("day after tomorrow", 2), Word("tomorrow", 1), Word("tmrw", 1), Word("tmr", 1),
        // 일본어
        Word("一昨日", -2), Word("おととい", -2),
        Word("昨日", -1), Word("きのう", -1), Word("昨夜", -1), Word("ゆうべ", -1),
        Word("本日", 0), Word("今日", 0), Word("きょう", 0), Word("今夜", 0), Word("今晩", 0),
        Word("明日", 1), Word("あした", 1), Word("あす", 1), Word("明晩", 1),
        Word("明後日", 2), Word("あさって", 2),
        Word("明々後日", 3), Word("しあさって", 3),
        // 중국어
        Word("前天", -2), Word("昨天", -1), Word("昨晚", -1),
        Word("今天", 0), Word("今晚", 0),
        Word("明天", 1), Word("明晚", 1),
        Word("大后天", 3), Word("大後天", 3), Word("后天", 2), Word("後天", 2),
    ]

    /// 요일. 값은 `Calendar` 의 weekday (일요일 = 1).
    ///
    /// 주말은 **토요일**로 읽는다. "주말에 청소" 는 토요일부터 시작하는 일이고,
    /// 요일과 같은 길로 처리하면 "다음 주말" 도 저절로 풀린다.
    static let weekdays: [Word<Int>] = [
        // 한국어
        Word("일요일", 1), Word("월요일", 2), Word("화요일", 3), Word("수요일", 4),
        Word("목요일", 5), Word("금요일", 6), Word("토요일", 7),
        Word("일욜", 1), Word("월욜", 2), Word("화욜", 3), Word("수욜", 4),
        Word("목욜", 5), Word("금욜", 6), Word("토욜", 7),
        Word("주말", 7),
        // 영어 — 세 글자 줄임말에서 "sun" 과 "sat" 은 뺐다. 해와 sat(앉다)로 훨씬 자주 쓰인다.
        Word("sunday", 1), Word("monday", 2), Word("tuesday", 3), Word("wednesday", 4),
        Word("thursday", 5), Word("friday", 6), Word("saturday", 7),
        Word("mon", 2), Word("tues", 3), Word("tue", 3), Word("wed", 4),
        Word("thurs", 5), Word("thur", 5), Word("thu", 5), Word("fri", 6),
        Word("weekend", 7),
        // 일본어
        Word("日曜日", 1), Word("月曜日", 2), Word("火曜日", 3), Word("水曜日", 4),
        Word("木曜日", 5), Word("金曜日", 6), Word("土曜日", 7),
        Word("日曜", 1), Word("月曜", 2), Word("火曜", 3), Word("水曜", 4),
        Word("木曜", 5), Word("金曜", 6), Word("土曜", 7),
        Word("週末", 7),
        // 중국어
        Word("星期日", 1), Word("星期天", 1), Word("星期一", 2), Word("星期二", 3),
        Word("星期三", 4), Word("星期四", 5), Word("星期五", 6), Word("星期六", 7),
        Word("周日", 1), Word("周天", 1), Word("周一", 2), Word("周二", 3),
        Word("周三", 4), Word("周四", 5), Word("周五", 6), Word("周六", 7),
        Word("週日", 1), Word("週一", 2), Word("週二", 3), Word("週三", 4),
        Word("週四", 5), Word("週五", 6), Word("週六", 7),
        Word("周末", 7),
    ]

    /// `다음 주` · `next week` · `来週` · `下周` — 이번 주로부터 몇 주.
    static let weekModifiers: [Word<Int>] = [
        // 한국어
        Word("다음 주", 1), Word("다음주", 1), Word("담주", 1), Word("낼주", 1),
        Word("이번 주", 0), Word("이번주", 0), Word("금주", 0),
        Word("지난 주", -1), Word("지난주", -1), Word("저번 주", -1), Word("저번주", -1),
        // 영어
        Word("next week", 1), Word("this week", 0), Word("last week", -1),
        // 일본어
        Word("来週", 1), Word("來週", 1), Word("今週", 0), Word("先週", -1),
        // 중국어
        Word("下个星期", 1), Word("下個星期", 1), Word("下星期", 1), Word("下周", 1), Word("下週", 1),
        Word("这个星期", 0), Word("这星期", 0), Word("这周", 0), Word("這週", 0),
        Word("本周", 0), Word("本週", 0),
        Word("上个星期", -1), Word("上星期", -1), Word("上周", -1), Word("上週", -1),
    ]

    /// 요일 **바로 앞**에 붙어 주를 옮기는 말. `next friday` · `다음 화요일`
    ///
    /// "다음 주" 같은 온전한 표현과 따로 두는 이유: 이 말들은 혼자 쓰이면
    /// 아무 뜻도 아니다. 요일에 붙어 있을 때만 본다.
    static let weekdayPrefixes: [Word<Int>] = [
        Word("다음", 1), Word("담", 1), Word("이번", 0), Word("지난", -1), Word("저번", -1),
        Word("next", 1), Word("this", 0), Word("last", -1),
        Word("来", 1), Word("來", 1), Word("今", 0), Word("先", -1),
        Word("下", 1), Word("上", -1), Word("这", 0), Word("這", 0), Word("本", 0),
    ]

    /// `다음 달` · `next month` · `来月` · `下个月` — 이번 달로부터 몇 달.
    static let monthModifiers: [Word<Int>] = [
        Word("다음 달", 1), Word("다음달", 1), Word("담달", 1),
        Word("이번 달", 0), Word("이번달", 0),
        Word("지난 달", -1), Word("지난달", -1),
        Word("next month", 1), Word("this month", 0), Word("last month", -1),
        Word("来月", 1), Word("來月", 1), Word("今月", 0), Word("先月", -1),
        Word("下个月", 1), Word("下個月", 1), Word("下月", 1),
        Word("这个月", 0), Word("這個月", 0), Word("本月", 0),
        Word("上个月", -1), Word("上個月", -1), Word("上月", -1),
    ]

    /// `이틀 뒤` — 숫자로 적지 않는 한국어 날수.
    static let nativeDayCounts: [Word<Int>] = [
        Word("하루", 1), Word("이틀", 2), Word("사흘", 3), Word("나흘", 4),
        Word("닷새", 5), Word("엿새", 6), Word("이레", 7), Word("여드레", 8),
        Word("아흐레", 9), Word("열흘", 10),
    ]

    // MARK: 시각 낱말

    /// `새벽` · `아침` · `저녁` · `evening` · `夕方` · `晚上` — 하루 중 때.
    static let periods: [Word<DayPart>] = [
        // 한국어
        Word("새벽", .dawn), Word("아침", .morning), Word("오전", .forenoon),
        Word("점심", .midday), Word("정오", .midday), Word("낮", .midday),
        Word("오후", .afternoon), Word("초저녁", .evening), Word("저녁", .evening),
        Word("한밤중", .night), Word("밤중", .night), Word("밤", .night),
        Word("자정", .midnight),
        // 영어
        Word("early morning", .dawn), Word("dawn", .dawn), Word("sunrise", .dawn),
        Word("morning", .morning), Word("forenoon", .forenoon),
        Word("midday", .midday), Word("noon", .midday), Word("lunchtime", .midday),
        Word("afternoon", .afternoon), Word("evening", .evening),
        Word("midnight", .midnight),
        Word("tonight", .night), Word("tonite", .night), Word("night", .night),
        // 일본어
        Word("明け方", .dawn), Word("未明", .dawn), Word("早朝", .morning), Word("朝", .morning),
        Word("午前", .forenoon), Word("正午", .midday), Word("お昼", .midday), Word("昼", .midday),
        Word("午後", .afternoon), Word("夕方", .evening), Word("夕暮れ", .evening),
        Word("真夜中", .midnight), Word("夜中", .night), Word("深夜", .night),
        Word("今夜", .night), Word("今晩", .night), Word("明晩", .night),
        Word("晩", .night), Word("夜", .night),
        // 중국어
        Word("凌晨", .dawn), Word("清晨", .dawn), Word("早晨", .morning), Word("早上", .morning),
        Word("上午", .forenoon), Word("中午", .midday),
        Word("下午", .afternoon), Word("傍晚", .evening), Word("晚上", .evening),
        Word("晚间", .evening), Word("晚間", .evening),
        Word("半夜", .midnight), Word("午夜", .midnight),
        Word("夜里", .night), Word("夜裡", .night), Word("今晚", .night), Word("明晚", .night),
        Word("昨晚", .night), Word("晚", .night),
    ]

    // MARK: 찾기

    /// 본문에서 **가장 앞선** 낱말. 같은 자리에서 겹치면 긴 쪽을 고른다
    /// (`一昨日` 이 `昨日` 을, `midnight` 이 `night` 를 이긴다).
    static func first<Value>(of table: [Word<Value>], in text: String) -> Match<Value>? {
        best(of: table, in: text, fromEnd: false)
    }

    /// 본문에서 **가장 뒤선** 낱말. 숫자 바로 앞에 붙은 때를 찾을 때 쓴다.
    static func last<Value>(of table: [Word<Value>], in text: String) -> Match<Value>? {
        best(of: table, in: text, fromEnd: true)
    }

    private static func best<Value>(
        of table: [Word<Value>], in text: String, fromEnd: Bool
    ) -> Match<Value>? {
        var winner: Match<Value>?
        for word in table {
            guard let range = range(of: word.text, in: text, fromEnd: fromEnd) else { continue }
            let found = Match(value: word.value, text: String(text[range]), range: range)
            guard let current = winner else {
                winner = found
                continue
            }
            if beats(found, current, fromEnd: fromEnd) { winner = found }
        }
        return winner
    }

    private static func beats<Value>(
        _ lhs: Match<Value>, _ rhs: Match<Value>, fromEnd: Bool
    ) -> Bool {
        if fromEnd {
            if lhs.range.upperBound != rhs.range.upperBound {
                return lhs.range.upperBound > rhs.range.upperBound
            }
        } else if lhs.range.lowerBound != rhs.range.lowerBound {
            return lhs.range.lowerBound < rhs.range.lowerBound
        }
        return lhs.text.count > rhs.text.count
    }

    /// 낱말 하나를 본문에서 찾는다.
    ///
    /// 라틴 문자로 시작하는 낱말은 **낱말 경계**를 지킨다 — "monday" 를 찾는데
    /// "money" 가 걸리면 안 되고, "afternoon" 안의 "noon" 도 아니다. 한글·한자·
    /// 가나는 띄어 쓰지 않고 붙여 쓰므로 경계를 따지지 않는다.
    static func range(
        of word: String, in text: String, fromEnd: Bool = false
    ) -> Range<String.Index>? {
        let options: String.CompareOptions = fromEnd
            ? [.caseInsensitive, .backwards]
            : [.caseInsensitive]
        var window = text.startIndex..<text.endIndex

        while !window.isEmpty,
              let found = text.range(of: word, options: options, range: window) {
            if !needsBoundary(word) || standsAlone(found, in: text) { return found }
            window = fromEnd
                ? text.startIndex..<found.lowerBound
                : text.index(after: found.lowerBound)..<text.endIndex
        }
        return nil
    }

    private static func needsBoundary(_ word: String) -> Bool {
        guard let first = word.first else { return false }
        return first.isASCII && first.isLetter
    }

    private static func standsAlone(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = range.lowerBound > text.startIndex
            ? text[text.index(before: range.lowerBound)]
            : nil
        let after = range.upperBound < text.endIndex ? text[range.upperBound] : nil
        return !isWordish(before) && !isWordish(after)
    }

    private static func isWordish(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber
    }
}

extension TimeWords.DayPart {
    /// 숫자 없이 때만 적었을 때 쓰는 대표 시각. "내일 저녁 약속" 은 19시다.
    ///
    /// **짐작이 들어가는 유일한 자리다.** 그래도 짐작하는 쪽을 골랐다 — "내일 저녁"
    /// 을 날짜만 붙은 메모로 두면 흐름에서 아침 일과 뒤섞이고, 사용자는 정확한
    /// 시각을 적을 생각이 애초에 없었다. 칩에 해석 결과가 그대로 보이므로
    /// 어긋나면 바로 눈에 띈다.
    var defaultHour: Int {
        switch self {
        case .dawn: 5
        case .morning: 8
        case .forenoon: 9
        case .midday: 12
        case .afternoon: 14
        case .evening: 19
        case .night: 21
        case .midnight: 0
        }
    }

    /// 적힌 숫자를 24시간제로 옮긴다. "저녁 7시" 는 19시, "밤 12시" 는 0시.
    func hour(from stated: Int) -> Int {
        switch self {
        case .dawn, .morning, .forenoon, .midnight:
            stated == 12 ? 0 : stated
        case .midday:
            // "점심 1시" 는 13시. 다만 "정오 12시" 는 그대로 둔다.
            stated < 6 ? stated + 12 : stated
        case .afternoon, .evening:
            stated < 12 ? stated + 12 : stated
        case .night:
            stated == 12 ? 0 : (stated < 12 ? stated + 12 : stated)
        }
    }
}
