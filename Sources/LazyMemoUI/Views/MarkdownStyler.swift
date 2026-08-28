import AppKit
import LazyMemoCore

/// 마크다운 원문 위에 **꾸밈만** 입힌다.
///
/// 글자는 절대 바꾸지 않는다 (`MarkdownScanner` 참고). `**굵게**` 를 치면
/// 그 자리에서 굵어지지만 파일에는 여전히 `**굵게**` 가 저장된다 — 정본이
/// 마크다운이라는 D4 와, 사용자가 언제든 텍스트 에디터로 열 수 있다는 약속이
/// 둘 다 지켜진다.
///
/// 마커(`**`, `#`, `[]()`)는 지우지 않고 **흐리게 눌러 둔다.** 지우면 커서가
/// 어디 있는지 알 수 없어지고, 되돌리기도 어긋난다.
enum MarkdownStyler {
    private typealias Span = MarkdownScanner.Span

    /// 눈에 보이지 않을 만큼 작은 글꼴. 글자를 지우지 않고 감추는 방법이다.
    private static let hiddenSize: CGFloat = 0.01

    /// - Parameter activeLine: 커서가 놓인 줄. 그 줄에서만 기호를 보여준다.
    static func apply(
        to storage: NSTextStorage,
        baseFont: NSFont,
        paragraph: NSParagraphStyle?,
        activeLine: NSRange? = nil
    ) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        defer { storage.endEditing() }

        // 매번 바탕부터 다시 깐다. 지운 마커의 흔적이 남지 않게 하는 가장 확실한 길이다.
        storage.setAttributes(baseAttributes(baseFont, paragraph), range: full)

        let spans = MarkdownScanner.spans(in: text)

        // 블록(제목·인용·체크)을 먼저, 인라인을 그 위에, 마커를 맨 마지막에.
        for span in spans where isBlock(span.kind) {
            style(span, in: storage, baseFont: baseFont, text: text)
        }
        for span in spans where !isBlock(span.kind) && span.kind != .syntax {
            style(span, in: storage, baseFont: baseFont, text: text)
        }
        for span in spans where span.kind == .syntax {
            style(span, in: storage, baseFont: baseFont, text: text)
        }

        // 기호는 **커서가 놓인 줄에서만** 보인다.
        //
        // 이것이 "치는 대로 꾸며진다" 를 완성한다. `## 제목` 이 그냥 큰 글씨로
        // 보이고, `[이름](주소)` 가 이름만 남는다. 글자를 지우는 것이 아니라
        // 보이지 않을 만큼 작게 만들 뿐이라 파일은 그대로다 — 그 줄로 커서를
        // 옮기면 기호가 되돌아와 고칠 수 있다.
        for span in spans where shouldHide(span, activeLine: activeLine) {
            hide(span.range, in: storage)
        }

        // 체크박스의 `- ` 도 감춘다. `[ ]` 만 남으면 그 자체가 체크상자로 읽히는데,
        // 앞에 붙임표가 있으면 다시 마크다운 원문으로 보인다.
        for span in spans {
            guard case .checkbox = span.kind, isOffActiveLine(span.range, activeLine) else { continue }
            let bracket = (text as NSString).range(of: "[", options: [], range: span.range).location
            guard bracket != NSNotFound, bracket > span.range.location else { continue }
            hide(NSRange(location: span.range.location, length: bracket - span.range.location), in: storage)
        }
    }

    private static func isOffActiveLine(_ range: NSRange, _ activeLine: NSRange?) -> Bool {
        guard let activeLine else { return true }
        return NSIntersectionRange(range, activeLine).length == 0
    }

    private static func shouldHide(_ span: Span, activeLine: NSRange?) -> Bool {
        switch span.kind {
        case .syntax, .image: break
        default: return false
        }
        return isOffActiveLine(span.range, activeLine)
    }

    private static func hide(_ range: NSRange, in storage: NSTextStorage) {
        guard range.location >= 0, range.location + range.length <= storage.length else { return }
        storage.addAttribute(.font, value: NSFont.systemFont(ofSize: hiddenSize), range: range)
    }

    static func baseAttributes(_ font: NSFont, _ paragraph: NSParagraphStyle?) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Paper.inkNSColor,
        ]
        if let paragraph { attributes[.paragraphStyle] = paragraph }
        return attributes
    }

    private static func isBlock(_ kind: MarkdownScanner.Span.Kind) -> Bool {
        switch kind {
        case .heading, .quote, .checkbox, .bullet: true
        default: false
        }
    }

    private static func style(
        _ span: MarkdownScanner.Span,
        in storage: NSTextStorage,
        baseFont: NSFont,
        text: String
    ) {
        let range = span.range
        guard range.location >= 0, range.location + range.length <= storage.length else { return }

        switch span.kind {
        case .heading(let level):
            // 1단계가 가장 크고, 내려갈수록 본문에 가까워진다.
            let bump: CGFloat = [7, 4, 2, 1, 0, 0][min(level, 6) - 1]
            storage.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: baseFont.pointSize + bump, weight: .semibold),
                range: range
            )

        case .strong:
            addTrait(.bold, to: storage, range: range, baseFont: baseFont)

        case .emphasis:
            addTrait(.italic, to: storage, range: range, baseFont: baseFont)

        case .code:
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular),
                .backgroundColor: NSColor(white: 0, alpha: 0.055),
            ], range: range)

        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)

        case .bullet:
            // 글머리 기호만 눌러 둔다. 목록의 내용은 본문과 같은 무게여야 한다.
            storage.addAttribute(.foregroundColor, value: Paper.inkNSColor.withAlphaComponent(0.45), range: range)

        case .quote:
            storage.addAttribute(.foregroundColor, value: Paper.inkNSColor.withAlphaComponent(0.62), range: range)
            addTrait(.italic, to: storage, range: range, baseFont: baseFont)

        case .checkbox(let done):
            storage.addAttribute(.foregroundColor, value: Paper.inkNSColor.withAlphaComponent(0.42), range: range)
            // `[ ]` `[x]` 는 고정폭으로 두면 그 자체가 체크상자로 읽힌다.
            if let bracket = (text as NSString).range(
                of: "[", options: [], range: range
            ).location as Int?, bracket != NSNotFound {
                let box = NSRange(location: bracket, length: 3)
                if box.location + box.length <= storage.length {
                    storage.addAttribute(
                        .font,
                        value: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                        range: box
                    )
                }
            }
            guard done else { return }
            // 끝낸 일은 줄을 긋고 물러난다. 지우라고 하지 않는다 (철학 1).
            let line = (text as NSString).lineRange(for: range)
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: Paper.inkNSColor.withAlphaComponent(0.42),
            ], range: line)

        case .link(let destination):
            storage.addAttributes([
                .foregroundColor: NSColor(Paper.linkColor),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: destination,
                .cursor: NSCursor.pointingHand,
            ], range: range)

        case .image:
            // 실제 그림은 본문 아래에 붙는다. 참조는 글 흐름을 막지 않도록
            // 작게 눌러 둔다 — 지우지는 않는다. 지우면 커서가 갈 곳을 잃는다.
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.62, weight: .regular),
                .foregroundColor: Paper.inkNSColor.withAlphaComponent(0.30),
            ], range: range)

        case .syntax:
            storage.addAttribute(.foregroundColor, value: Paper.inkNSColor.withAlphaComponent(0.22), range: range)
            // `](https://…)` 처럼 긴 마커는 색만 죽여서는 여전히 시끄럽다.
            // 글자 크기까지 줄이면 링크 이름만 남은 것처럼 보인다.
            guard range.length > 4 else { return }
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let current = (value as? NSFont) ?? baseFont
                storage.addAttribute(
                    .font,
                    value: NSFont.systemFont(ofSize: current.pointSize * 0.68),
                    range: subrange
                )
            }
        }
    }

    private static func addTrait(
        _ trait: NSFontDescriptor.SymbolicTraits,
        to storage: NSTextStorage,
        range: NSRange,
        baseFont: NSFont
    ) {
        // 이미 다른 꾸밈이 얹힌 글자도 있으므로 현재 글꼴에서 출발해 특성만 더한다.
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let current = (value as? NSFont) ?? baseFont
            let descriptor = current.fontDescriptor.withSymbolicTraits(
                current.fontDescriptor.symbolicTraits.union(trait)
            )
            if let font = NSFont(descriptor: descriptor, size: current.pointSize) {
                storage.addAttribute(.font, value: font, range: subrange)
            }
        }
    }
}
