import Foundation

/// 한글 **첫소리** — 「ㅈㅂㄱ」가 「장보기」를 찾게 하는 규칙.
///
/// 한국어를 쓰는 사람에게 「ㅈㅂㄱ」는 「장보기」의 준말이다. 이것이 없으면
/// 「장보」까지 온전히 쳐야 하고, 한글 입력에서 그것은 여섯 번의 타건이다.
/// 첫소리 찾기는 **한 번에 한 글자씩 좁혀지는** 유일한 길이다.
///
/// 첫소리 질의는 **질의가 통째로 첫소리일 때만** 그렇게 읽는다. 「ㄱ치과」처럼
/// 섞이면 보통 글자로 본다 — 섞인 것을 해석하기 시작하면 「ㄱ」가 낱말인지
/// 첫소리인지 사람이 예측할 수 없다.
///
/// 서랍(`DrawerSearch`)에서 먼저 태어났고, 빠른 입력이 같은 규칙을 쓰려고
/// 여기로 내려왔다. **찾는 상자가 둘인데 규칙이 다르면** 사람은 어느 쪽에서
/// 되는지를 외워야 하고, 그것은 이 앱이 하지 않기로 한 일이다 (§7.1).
public enum HangulInitials {

    /// 한글 음절이 시작되는 코드 값과 한 초성이 거느리는 음절 수.
    private static let syllableBase: UInt32 = 0xAC00
    private static let syllableCount: UInt32 = 588

    /// 초성 열아홉. 차례가 곧 유니코드 차례다.
    private static let leads = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    /// 대소문자와 발음기호를 지운 꼴. 견주기 전에 양쪽을 같은 자리에 세운다.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// 글의 **첫소리만** 뽑는다. 한글이 아닌 글자는 그대로 남는다 —
    /// 「ios 회의」의 첫소리는 「ios ㅎㅇ」다.
    public static func initials(of text: String) -> String {
        String(text.map { character in
            guard let scalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1,
                  scalar.value >= syllableBase,
                  scalar.value < syllableBase + syllableCount * UInt32(leads.count)
            else { return character }
            let index = Int((scalar.value - syllableBase) / syllableCount)
            return leads[index]
        })
    }

    /// 이 질의를 **첫소리로 읽어야 하는가** — 통째로 초성일 때만 그렇다.
    public static func isInitialsQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { leads.contains($0) }
    }

    /// 이 글이 질의에 걸리는가. 보통 글자로 먼저 견주고, 질의가 통째로
    /// 첫소리일 때만 첫소리로도 견준다.
    public static func matches(_ haystack: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }

        let folded = normalize(haystack)
        if folded.contains(normalize(trimmed)) { return true }

        guard isInitialsQuery(trimmed) else { return false }
        return initials(of: folded).contains(trimmed)
    }
}
