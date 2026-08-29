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
            style(span, in: storage, baseFont: baseFont, paragraph: paragraph, text: text)
        }
        for span in spans where !isBlock(span.kind) && span.kind != .syntax {
            style(span, in: storage, baseFont: baseFont, paragraph: paragraph, text: text)
        }
        for span in spans where span.kind == .syntax {
            style(span, in: storage, baseFont: baseFont, paragraph: paragraph, text: text)
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

        // 줄머리 표시(`- `, `- [ ] `, `> `)는 감추고 **왼쪽 여백에 자리를 만든다.**
        // 그 자리에 진짜 체크상자와 점을 그리는 것은 `MemoNSTextView` 다.
        //
        // 마커를 글자로 남겨 두면 `[x]` 같은 원문이 그대로 보여, "치는 대로
        // 꾸며진다" 는 약속이 반만 지켜진 상태로 오히려 더 어색해진다.
        for span in spans {
            guard let marker = lineMarker(for: span.kind),
                  isOffActiveLine(span.range, activeLine),
                  let markerRange = markerRange(for: span, kind: marker, spans: spans)
            else { continue }
            place(marker, markerRange: markerRange, in: storage, text: text, paragraph: paragraph)
        }
    }

    /// 사진 참조(`![](…)`)만 감춘다. **꾸밈은 입히지 않는다.**
    ///
    /// 빠른 입력은 마크다운 꾸밈을 켜지 않는다 — 한 줄 적고 마는 자리에서
    /// 치는 동안 글자가 움직이면 방해가 되기 때문이다. 그런데 사진을 붙이면
    /// 40자짜리 경로가 19pt 로 말풍선을 가득 채워, **붙여넣기가 성공한 화면이
    /// 오히려 고장 난 것처럼 보였다.**
    ///
    /// 붙었다는 것은 조각(`PhotoChip`)이 이미 말한다. 그러니 경로는 감추기만
    /// 하면 된다. 여기서도 글자는 지우지 않는다 (D4) — 커서를 그 줄로 옮기면
    /// 도로 보여 고칠 수 있는 것까지 메모 창과 같다.
    static func hideImageReferences(
        to storage: NSTextStorage,
        baseFont: NSFont,
        paragraph: NSParagraphStyle?,
        activeLine: NSRange? = nil
    ) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.setAttributes(baseAttributes(baseFont, paragraph), range: full)
        for span in MarkdownScanner.spans(in: text) {
            guard case .image = span.kind, isOffActiveLine(span.range, activeLine) else { continue }
            hide(span.range, in: storage)
        }
    }

    // MARK: 줄머리 표시

    private static func lineMarker(for kind: Span.Kind) -> LineMarker? {
        switch kind {
        case .bullet: .bullet
        case .quote: .quote
        case .checkbox(let done): done ? .checked : .unchecked
        default: nil
        }
    }

    /// 감출 마커 글자의 구간.
    ///
    /// 붙임표·체크상자는 스캐너가 마커만 딱 잘라 주지만, 인용은 줄 전체가
    /// 구간이고 `> ` 는 같은 자리에서 시작하는 별도 `.syntax` 구간으로 온다.
    private static func markerRange(for span: Span, kind: LineMarker, spans: [Span]) -> NSRange? {
        guard kind == .quote else { return span.range }
        return spans.first {
            $0.kind == .syntax && $0.range.location == span.range.location
        }?.range
    }

    private static func place(
        _ marker: LineMarker,
        markerRange: NSRange,
        in storage: NSTextStorage,
        text: String,
        paragraph: NSParagraphStyle?
    ) {
        let source = text as NSString
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        source.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: markerRange)

        hide(markerRange, in: storage)

        // 들여쓰기가 표시를 그릴 여백을 만든다. 줄이 넘어가도 글이 가지런하다.
        let style = (paragraph?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = marker.gutter
        style.headIndent = marker.gutter
        storage.addAttribute(
            .paragraphStyle, value: style,
            range: NSRange(location: lineStart, length: lineEnd - lineStart)
        )

        // 표시는 **내용 구간**에 붙인다 — 감춘 마커는 글꼴이 0.01pt 라
        // 기준선을 물어보면 엉뚱한 높이가 나온다.
        let contentStart = markerRange.location + markerRange.length
        guard contentsEnd > contentStart else { return }
        storage.addAttribute(
            .lineMarker, value: marker.rawValue,
            range: NSRange(location: contentStart, length: contentsEnd - contentStart)
        )
    }

    /// 화면 밖 렌더 전용 — 감춘 줄머리 마커를 눈에 보이는 글리프로 바꿔 끼운다.
    ///
    /// 편집기에서는 **절대 하지 않는다.** 글자를 바꾸면 파일도 커서도 어긋난다
    /// (D4, §8). 미리보기는 돌아갈 원문이 없는 사본이라 안전하고, 이걸 해야
    /// `render-ui.sh` 로 실제 화면과 같은 것을 눈으로 확인할 수 있다 —
    /// SwiftUI `Text` 는 여백에 직접 그리는 `LineMarker` 를 그릴 수 없기 때문이다.
    static func substituteMarkersForPreview(in storage: NSTextStorage, baseFont: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        var found: [(NSRange, LineMarker)] = []
        storage.enumerateAttribute(.lineMarker, in: full) { value, range, _ in
            guard let raw = value as? Int, let marker = LineMarker(rawValue: raw) else { return }
            found.append((range, marker))
        }

        // 뒤에서부터 바꿔야 앞 구간의 위치가 흔들리지 않는다.
        for (range, marker) in found.reversed() {
            let source = storage.string as NSString
            let lineStart = source.lineRange(for: range).location
            let markerRange = NSRange(location: lineStart, length: range.location - lineStart)
            guard markerRange.length > 0 else { continue }

            // 속성을 내용 첫 글자에서 베끼면 안 된다 — `**계란**` 처럼 내용이
            // 마커로 시작하는 줄에서는 감춰 둔 0.01pt 글꼴을 물려받아 글리프가
            // 통째로 사라진다. 바탕 글꼴에서 새로 짓는다.
            var attributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: Paper.inkNSColor.withAlphaComponent(0.38),
            ]
            // 글리프가 여백을 차지하므로 첫 줄 들여쓰기는 되돌린다.
            if let style = (storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
                style.firstLineHeadIndent = 0
                attributes[.paragraphStyle] = style
            }

            storage.replaceCharacters(
                in: markerRange,
                with: NSAttributedString(string: marker.previewGlyph, attributes: attributes)
            )
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
        paragraph: NSParagraphStyle?,
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
            // 제목 아래에 숨 쉴 자리를 준다. 바로 다음 줄이 붙으면 제목이
            // 제목으로 안 읽히고 그냥 굵은 첫 줄이 된다.
            let spaced = (paragraph?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            spaced.paragraphSpacing = 6
            storage.addAttribute(.paragraphStyle, value: spaced, range: range)

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
            // 줄을 긋는 것은 **내용에만** — 감춘 마커까지 그으면 여백에
            // 정체 모를 짧은 선이 남는다.
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            (text as NSString).getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: range)
            let contentStart = range.location + range.length
            guard contentsEnd > contentStart else { return }
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: Paper.inkNSColor.withAlphaComponent(0.42),
            ], range: NSRange(location: contentStart, length: contentsEnd - contentStart))

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
