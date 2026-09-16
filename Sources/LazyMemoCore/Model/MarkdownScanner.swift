import Foundation

/// 마크다운 원문에서 꾸밀 구간을 찾아낸다.
///
/// **글자를 바꾸지 않는다.** 파일이 정본이므로(D4) 편집기는 사용자가 친 마크다운
/// 그대로를 들고 있어야 하고, 우리는 그 위에 입힐 속성의 **구간만** 계산한다.
/// 원문을 건드리는 순간 한글 조합(§8)도, 저장 내용도 함께 망가진다.
///
/// AppKit 밖에 두는 이유는 구간 계산이 경계에서 틀리기 쉬워서다 — 테스트로 못 박는다.
public enum MarkdownScanner {
    public struct Span: Sendable, Equatable {
        public enum Kind: Sendable, Equatable {
            case heading(level: Int)
            case strong
            case emphasis
            case code
            case strikethrough
            case bullet
            case quote
            case checkbox(done: Bool)
            case link(destination: String)
            case image(path: String)
            /// 본문 끝의 「## 가는 길」 절 통째로 (`RouteNote`). 카드가 대신 서므로 편집기는 감춘다.
            case route
            /// 마커 자체 (`**`, `#`, `[]()`). 흐리게 눌러 둔다.
            case syntax
        }

        public let range: NSRange
        public let kind: Kind

        public init(range: NSRange, kind: Kind) {
            self.range = range
            self.kind = kind
        }
    }

    public static func spans(in text: String) -> [Span] {
        let source = text as NSString
        var result: [Span] = []

        source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: [.byLines]) {
            line, lineRange, _, _ in
            guard let line else { return }
            result.append(contentsOf: scanLine(line, at: lineRange, in: text))
        }

        // 가는 길의 절은 한 덩어리다 — 줄마다 감추면 커서가 한 줄에 들어갔을 때 그 줄만 보인다.
        if let section = RouteNote.sectionRange(in: text) {
            result.append(Span(range: NSRange(section, in: text), kind: .route))
        }

        return result
    }

    // MARK: 줄 단위

    private static func scanLine(_ line: String, at lineRange: NSRange, in text: String) -> [Span] {
        var result: [Span] = []
        var contentStart = 0   // 줄 안에서 인라인 검사를 시작할 위치

        if let match = line.wholeMatch(of: /(#{1,6})[ \t]+(.*)/) {
            let markerLength = (String(match.1) as NSString).length
            result.append(Span(
                range: NSRange(location: lineRange.location, length: lineRange.length),
                kind: .heading(level: markerLength)
            ))
            result.append(Span(
                range: NSRange(location: lineRange.location, length: markerLength + 1),
                kind: .syntax
            ))
            contentStart = markerLength + 1
        } else if let match = line.firstMatch(of: /^([ \t]*)([-*])[ \t]+\[([ xX])\][ \t]/) {
            let markerLength = (String(match.0) as NSString).length
            result.append(Span(
                range: NSRange(location: lineRange.location, length: markerLength),
                kind: .checkbox(done: match.3 != " ")
            ))
            contentStart = markerLength
        } else if let match = line.firstMatch(of: /^([ \t]*)([-*+])[ \t]+/) {
            let markerLength = (String(match.0) as NSString).length
            result.append(Span(
                range: NSRange(location: lineRange.location, length: markerLength),
                kind: .bullet
            ))
            contentStart = markerLength
        } else if let match = line.firstMatch(of: /^[ \t]*>[ \t]?/) {
            let markerLength = (String(match.0) as NSString).length
            result.append(Span(
                range: NSRange(location: lineRange.location, length: lineRange.length),
                kind: .quote
            ))
            result.append(Span(
                range: NSRange(location: lineRange.location, length: markerLength),
                kind: .syntax
            ))
            contentStart = markerLength
        }

        let body = (line as NSString)
        guard contentStart < body.length else { return result }
        let remainder = body.substring(from: contentStart)
        result.append(contentsOf: scanInline(remainder, offset: lineRange.location + contentStart))
        return result
    }

    // MARK: 인라인

    /// 순서가 중요하다. 이미지는 링크보다 먼저(`![]()` 가 `[]()` 를 품는다),
    /// 코드는 강조보다 먼저(`` `**` `` 안의 별표는 강조가 아니다) 본다.
    private static func scanInline(_ text: String, offset: Int) -> [Span] {
        var result: [Span] = []
        var claimed: [NSRange] = []

        func add(_ range: NSRange, _ kind: Span.Kind, markers: [NSRange] = []) {
            guard !claimed.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { return }
            claimed.append(range)
            result.append(Span(range: range, kind: kind))
            for marker in markers {
                result.append(Span(range: marker, kind: .syntax))
            }
        }

        func nsRange(_ range: Range<String.Index>) -> NSRange {
            let converted = NSRange(range, in: text)
            return NSRange(location: converted.location + offset, length: converted.length)
        }

        for match in text.matches(of: /!\[([^\]]*)\]\(([^)]+)\)/) {
            let whole = nsRange(match.range)
            add(whole, .image(path: String(match.2)), markers: [whole])
        }

        for match in text.matches(of: /\[([^\]]*)\]\(([^)]+)\)/) {
            let whole = nsRange(match.range)
            let label = nsRange(match.1.startIndex..<match.1.endIndex)
            add(whole, .link(destination: String(match.2)), markers: [
                NSRange(location: whole.location, length: label.location - whole.location),
                NSRange(location: label.location + label.length,
                        length: whole.location + whole.length - label.location - label.length),
            ])
        }

        // 벌거벗은 URL 도 링크로 본다. 사용자가 그냥 붙여넣는 경우가 대부분이다.
        for match in text.matches(of: /https?:\/\/[^\s<>()\[\]]+/) {
            add(nsRange(match.range), .link(destination: String(match.0)))
        }

        for match in text.matches(of: /`([^`\n]+)`/) {
            let whole = nsRange(match.range)
            add(whole, .code, markers: [
                NSRange(location: whole.location, length: 1),
                NSRange(location: whole.location + whole.length - 1, length: 1),
            ])
        }

        for match in text.matches(of: /\*\*([^*\n]+)\*\*/) {
            let whole = nsRange(match.range)
            add(whole, .strong, markers: [
                NSRange(location: whole.location, length: 2),
                NSRange(location: whole.location + whole.length - 2, length: 2),
            ])
        }

        for match in text.matches(of: /~~([^~\n]+)~~/) {
            let whole = nsRange(match.range)
            add(whole, .strikethrough, markers: [
                NSRange(location: whole.location, length: 2),
                NSRange(location: whole.location + whole.length - 2, length: 2),
            ])
        }

        for match in text.matches(of: /(?:\*|_)([^*_\n]+)(?:\*|_)/) {
            let whole = nsRange(match.range)
            add(whole, .emphasis, markers: [
                NSRange(location: whole.location, length: 1),
                NSRange(location: whole.location + whole.length - 1, length: 1),
            ])
        }

        return result
    }

    /// 본문에 들어 있는 링크 주소를 순서대로, 중복 없이 모은다.
    ///
    /// 같은 주소를 두 번 적었다고 카드가 두 장 붙으면 종이가 시끄러워진다.
    public static func linkDestinations(in text: String) -> [String] {
        var seen: Set<String> = []
        return spans(in: text).compactMap {
            guard case .link(let destination) = $0.kind else { return nil }
            guard destination.lowercased().hasPrefix("http") else { return nil }
            return seen.insert(destination).inserted ? destination : nil
        }
    }

    /// 본문의 체크상자를 **줄 차례대로** 모은다. 값은 체크됐는지 여부다.
    ///
    /// 다 끝난 목록이 스스로 물러나는 규칙(`Tidy`)이 이것을 읽는다. 화면이
    /// 아니라 여기서 세는 이유는 그 규칙이 화면 없이 서야 하기 때문이다.
    public static func checkboxes(in text: String) -> [Bool] {
        spans(in: text).compactMap {
            if case .checkbox(let done) = $0.kind { return done }
            return nil
        }
    }

    /// 본문에 들어 있는 이미지 경로를 순서대로 모은다.
    public static func imagePaths(in text: String) -> [String] {
        spans(in: text).compactMap {
            if case .image(let path) = $0.kind { return path }
            return nil
        }
    }
}
