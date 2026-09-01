import LazyMemoCore

/// 종이 아래 한 줄에 무엇이 적히는가.
///
/// 규칙을 뷰 밖으로 꺼내 둔 이유는 **아무것도 안 뜨는 실패가 화면에서 보이지
/// 않기 때문**이다. 장소만 적힌 메모에 이 줄이 아예 서지 않으면 사용자는 장소를
/// 적었다는 것조차 알 수 없고, 그건 «잃어버렸다» 와 구별되지 않는다.
enum NoteFooter {
    /// 이 메모에 아래 줄이 서는가.
    static func isVisible(for memo: Memo) -> Bool {
        memo.isScheduled || memo.surface != nil || memo.hasPlace || !memo.tags.isEmpty
    }

    /// 잉크에 적히는 장소 이름. 좌표만 있으면 좌표를 적는다 — 빈 잉크는 없다.
    static func placeLabel(for memo: Memo) -> String? {
        if let place = memo.place, !place.isEmpty { return place }
        return memo.geo?.description
    }
}

/// 달력 줄과 종이가 **같은 낱말**을 쓰게 한다.
///
/// 화면에 적힌 것과 소리로 읽는 것이 다르면 조용한 화면이 거기서는 알아들을 수
/// 없는 화면이 된다 (§14.11). 그래서 보이는 줄과 VoiceOver 가 읽는 줄을 한
/// 함수에서 만든다 — 한쪽만 고쳐지는 일이 없도록.
enum RowWords {
    /// 눈으로 읽는 한 줄: `14:00 치과 · 강남역`.
    static func line(clock: String, title: String, place: String?) -> String {
        join(clock: clock, title: title, place: place, separator: "·")
    }

    /// 소리로 듣는 한 줄. 가운뎃점은 읽히지 않으므로 쉼표로 바꾼다.
    static func spoken(clock: String, title: String, place: String?) -> String {
        join(clock: clock, title: title, place: place, separator: ",")
    }

    private static func join(
        clock: String, title: String, place: String?, separator: String
    ) -> String {
        var words: [String] = []
        if !clock.isEmpty { words.append(clock) }
        words.append(title)
        if let place, !place.isEmpty {
            if separator == "," {
                words[words.count - 1] += ","
                words.append(place)
            } else {
                words.append(separator)
                words.append(place)
            }
        }
        return words.joined(separator: " ")
    }
}
