import Foundation

/// 목록 줄의 편집 규칙 — **⏎ 가 머리를 잇고, 빈 항목의 ⏎ 는 머리를 떼고, 체크상자는 눌러 뒤집는다.**
///
/// `- [ ] 우유` 를 치고 ⏎ 를 누른 사람이 다음 줄에 `- [ ] ` 를 다시 치게 하는 것은 형식을 배우게 하는
/// 일이다(철학 1). 머리는 앱이 잇고, 더 적을 것이 없어 빈 머리에서 ⏎ 를 치면 목록에서 나온다 —
/// Notes·Bear 와 같은 손짓이라 새로 배울 것이 없다.
///
/// 맥의 `MemoNSTextView` 와 폰의 `PaperTextView` 가 **같은 답**을 받는다. 여기서는 글자를 어떻게
/// 바꿀지만 계산하고, 실제로 바꾸는 것은 편집기다 — 그래야 되돌리기와 조합 상태가 편집기의 것으로
/// 이어진다. 파일이 정본이라(D4) 내놓는 것은 언제나 사람이 읽는 마크다운이고, 머리의 모양(`-`·`*`·
/// 들여쓰기)은 사람이 쓴 그대로 따른다.
public enum ListEditing {
    /// 글에 가할 한 번의 바꿈 — `range` 를 `replacement` 로.
    public struct Edit: Sendable, Equatable {
        public let range: NSRange
        public let replacement: String

        public init(range: NSRange, replacement: String) {
            self.range = range
            self.replacement = replacement
        }

        /// 바꾼 뒤 커서가 설 자리 — 넣은 글의 끝.
        public var caret: Int { range.location + (replacement as NSString).length }
    }

    /// 줄머리 — 사람이 쓴 모양 그대로와, 다음 줄에 이을 모양.
    struct Head: Equatable {
        /// 머리 글자 수 (들여쓰기 포함, 내용 앞 빈칸까지).
        let length: Int
        /// 다음 항목의 머리. 체크상자는 빈 칸으로, 번호는 하나 더한 것으로.
        let next: String

        /// 머리 뒤의 빈칸은 **하나만** 머리로 친다 — 나머지는 내용이다(빈칸뿐이면 빈 항목). 그래야 「- 」 뒤에
        /// 빈칸을 더 친 줄에서도 커서가 머리 안이 아니라 내용에 선 것으로 읽힌다.
        init?(line: String) {
            if let match = line.firstMatch(of: /^([ \t]*)([-*+])[ \t]+\[[ xX]\][ \t]?/) {
                length = (String(match.0) as NSString).length
                next = "\(match.1)\(match.2) [ ] "
            } else if let match = line.firstMatch(of: /^([ \t]*)([-*+])[ \t]/) {
                length = (String(match.0) as NSString).length
                next = "\(match.1)\(match.2) "
            } else if let match = line.firstMatch(of: /^([ \t]*)(\d{1,3})\.[ \t]/), let number = Int(match.2) {
                length = (String(match.0) as NSString).length
                next = "\(match.1)\(number + 1). "
            } else if let match = line.firstMatch(of: /^([ \t]*)>[ \t]?/) {
                length = (String(match.0) as NSString).length
                next = "\(match.1)> "
            } else {
                return nil
            }
        }
    }

    /// ⏎ 를 쳤을 때. 목록 줄이 아니면 `nil` — 그때는 그냥 줄바꿈이다.
    ///
    /// - 머리 뒤에 내용이 있으면 **잇는다**: 커서 자리에 줄바꿈과 같은 머리. 커서 뒤의 글은 새 항목으로
    ///   내려간다(줄 가운데서 친 ⏎ 는 항목을 둘로 가르는 손이다).
    /// - 머리만 있고 내용이 비었으면 **머리를 뗀다** — 목록이 끝났다는 뜻이다. 줄은 빈 줄이 된다.
    /// - 커서가 머리 **안**에 있으면 그냥 줄바꿈 — 항목을 아래로 밀어 내리는 손이다.
    public static func onReturn(in text: String, selection: NSRange) -> Edit? {
        let source = text as NSString
        guard selection.location >= 0, NSMaxRange(selection) <= source.length else { return nil }

        let line = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let content = source.substring(with: line).trimmingTrailingNewlines()
        guard let head = Head(line: content) else { return nil }
        guard selection.location >= line.location + head.length else { return nil }

        let body = (content as NSString).substring(from: head.length)
        if body.allSatisfy(\.isWhitespace) {
            return Edit(range: NSRange(location: line.location, length: (content as NSString).length), replacement: "")
        }
        return Edit(range: selection, replacement: "\n" + head.next)
    }

    /// `location` 이 놓인 줄이 체크상자 줄이면 그 칸을 뒤집는 바꿈 — `[ ]` ↔ `[x]`. 아니면 `nil`.
    ///
    /// 게으른 사람에게 「다 했다」를 알리려고 글자를 고치게 하는 것은 불편의 극치다(맥의 `toggleCheckbox`
    /// 와 같은 말). 바꾸는 글자는 괄호 안 **한 글자**뿐이라 파일도 커서도 어긋나지 않는다.
    public static func toggleCheckbox(inLineContaining location: Int, in text: String) -> Edit? {
        let source = text as NSString
        guard location >= 0, location <= source.length else { return nil }
        let line = source.lineRange(for: NSRange(location: location, length: 0))
        let content = source.substring(with: line)
        guard let match = content.firstMatch(of: /^[ \t]*[-*+][ \t]+\[([ xX])\][ \t]/) else { return nil }
        let bracket = (content as NSString).range(of: "[").location
        guard bracket != NSNotFound else { return nil }
        let slot = NSRange(location: line.location + bracket + 1, length: 1)
        return Edit(range: slot, replacement: match.1 == " " ? "x" : " ")
    }
}

private extension String {
    /// 끝의 줄바꿈만 뗀다 — `lineRange` 가 물고 오는 `\n`·`\r\n`.
    func trimmingTrailingNewlines() -> String {
        var end = endIndex
        while end > startIndex, self[index(before: end)].isNewline { end = index(before: end) }
        return String(self[..<end])
    }
}
