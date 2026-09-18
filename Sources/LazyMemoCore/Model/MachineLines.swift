import Foundation

/// 본문에서 **기계가 적은 구간** — 사진 참조(`![](attachments/…)`)와 「## 가는 길」 절, 그리고 링크의 기호(`[`·`](주소)`).
///
/// 파일에는 그대로 있다 (D4 — 정본은 마크다운). 화면에서는 카드가 대신 서므로 글 칸의
/// 그 글자는 자리만 차지한다. 맥의 편집기는 기호를 커서가 든 줄에서만 되살리는 규칙으로 감추되
/// 사진 참조만은 커서 줄에서도 감춘다 (`MarkdownStyler`, 2026-09-18). 폰의 글 칸은 마크다운을
/// 꾸미지 않아 2026-09-17 까지 날것으로 보였다 — 사용자: 「경로를 만들면 텍스트가 안 보이게 해
/// 주고, 사진 붙이면 사진만 보이게」.
///
/// 여기 있는 것은 **어디를 감추고, 커서를 어디로 보내고, 지우기를 어디까지 넓힐지**뿐이다 —
/// 글자를 바꾸지 않는다.
public enum MachineLines {
    public enum Kind: Sendable, Equatable {
        case photo
        case route
        /// `[이름](주소)` 의 `[` 와 `](주소)` — 이름만 남는다. 맥에서 붙인 주소는 `LinkLabel` 이 이 꼴로 적는다.
        case linkSyntax
    }

    public struct Hidden: Sendable, Equatable {
        public let range: NSRange
        public let kind: Kind

        public init(range: NSRange, kind: Kind) {
            self.range = range
            self.kind = kind
        }

        var end: Int { range.location + range.length }
    }

    /// 감출 구간들 — 앞에서부터, 겹치지 않게.
    ///
    /// 사진 참조가 줄을 혼자 차지하면 그 줄의 줄바꿈까지 감춘다 — 글자만 감추면 빈 줄 하나가 남아
    /// 사진마다 종이가 한 줄씩 늘어진다. 글 사이에 낀 참조(`영수증 ![](…) 3월분`)는 참조만.
    /// 가는 길의 절은 `RouteNote.sectionRange` 그대로 — 뒤의 빈 줄까지, 앞의 빈 줄은 두고.
    public static func hidden(in text: String) -> [Hidden] {
        let source = text as NSString
        var result: [Hidden] = []
        let spans = MarkdownScanner.spans(in: text)
        // 링크의 기호는 별도 `.syntax` 구간으로 온다 — 링크 구간 안에 든 것만 링크의 것이다 (`#`·`**` 는 아니다).
        let links = spans.compactMap { span -> NSRange? in
            guard case .link = span.kind else { return nil }
            return span.range
        }
        for span in spans {
            switch span.kind {
            case .image:
                result.append(Hidden(range: wholeLineIfAlone(span.range, in: source), kind: .photo))
            case .route:
                result.append(Hidden(range: span.range, kind: .route))
            case .syntax where links.contains(where: { NSIntersectionRange($0, span.range).length == span.range.length }):
                result.append(Hidden(range: span.range, kind: .linkSyntax))
            default:
                continue
            }
        }
        result.sort { $0.range.location < $1.range.location }
        // 절 안의 참조는 절이 이미 품고 있다.
        var merged: [Hidden] = []
        for hidden in result {
            if let last = merged.last, NSIntersectionRange(last.range, hidden.range).length > 0 || last.end >= hidden.end { continue }
            merged.append(hidden)
        }
        return merged
    }

    /// 커서가 감춘 구간에 들어갔으면 밖으로 — 보이지 않는 곳에 친 글자는 잃은 글자다.
    ///
    /// 사진 참조·링크 기호 안이면 그 **뒤**로(사이에 글자가 끼면 참조·주소가 깨진다). 절 안이거나 절의
    /// 머리·끝이면 절 **앞**으로 — 「## 가는 길」 앞에 글자가 붙으면 제목이 아니게 되어 절 전체가 날것으로
    /// 드러나고 카드가 사라진다. 절 바로 앞이 줄바꿈이면 그 앞(절 위의 빈 줄)에 선다.
    /// 선택 구간(길이가 있는 것)은 건드리지 않는다 — 사람이 일부러 잡은 것이다.
    public static func caret(_ location: Int, avoiding hidden: [Hidden], in text: String) -> Int {
        let source = text as NSString
        for item in hidden {
            switch item.kind {
            case .photo, .linkSyntax:
                if location > item.range.location, location < item.end { return item.end }
            case .route:
                guard location >= item.range.location, location <= item.end else { continue }
                var target = item.range.location
                if target > 0, source.character(at: target - 1) == 0x0A { target -= 1 }
                return target
            }
        }
        return location
    }

    /// 지우려는 구간이 사진 참조에 걸치면 참조 전체로 넓힌다 — 사진은 한 덩이다.
    ///
    /// 참조는 감춰져 있으니 ⌫ 를 치는 사람은 빈 자리를 지운다고 안다. 그런데 `)` 하나만 떼면 그것은 더는
    /// 참조가 아니라 날것의 40자 경로가 되어 드러난다 — docx 의 그림처럼 한 번에 사라져야 한다 (2026-09-18
    /// 사용자). 참조만 본다(줄바꿈은 두고): 그 줄 뒤에서 친 첫 ⌫ 는 빈 줄을 거두고, 둘째가 사진을 뗀다.
    /// 파일은 남는다 — 되돌리기로 참조가 돌아오면 사진도 돌아와야 하고, 고아는 정리가 거둔다.
    public static func deletion(_ range: NSRange, in text: String) -> NSRange {
        var result = range
        for span in MarkdownScanner.spans(in: text) {
            guard case .image = span.kind, NSIntersectionRange(span.range, range).length > 0 else { continue }
            result = NSUnionRange(result, span.range)
        }
        return result
    }

    /// 사진 한 장을 뗀 본문 — 참조가 줄을 혼자 차지했으면 그 줄째. 폰의 사진 카드가 「사진 떼기」로 부른다:
    /// 참조가 감춰져 있으니 글 칸에서 지울 길이 없고, 카드가 그 사진의 자리이므로 떼는 것도 카드에서.
    public static func removingPhoto(_ path: String, from body: String) -> String {
        let source = body as NSString
        let spans = MarkdownScanner.spans(in: body).filter { if case .image(let found) = $0.kind { return found == path } else { return false } }
        guard !spans.isEmpty else { return body }
        var result = body
        for span in spans.sorted(by: { $0.range.location > $1.range.location }) {
            let range = wholeLineIfAlone(span.range, in: source)
            guard let swiftRange = Range(range, in: body) else { continue }
            result.removeSubrange(swiftRange)
        }
        while result.hasSuffix("\n") { result.removeLast() }
        return result
    }

    /// 참조 하나가 줄의 전부면 줄바꿈까지 — 없으면(글 끝) 참조만.
    private static func wholeLineIfAlone(_ range: NSRange, in source: NSString) -> NSRange {
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        source.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: range)
        let before = source.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
        let after = source.substring(with: NSRange(location: range.location + range.length, length: contentsEnd - range.location - range.length))
        guard before.allSatisfy(\.isWhitespace), after.allSatisfy(\.isWhitespace) else { return range }
        return NSRange(location: lineStart, length: lineEnd - lineStart)
    }
}
