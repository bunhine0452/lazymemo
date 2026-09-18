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
///
/// 사진 참조(`![](attachments/…)`)만은 **커서 줄에서도 감춘다.** 사진은 글 아래에 실물로 서고
/// 참조는 기계가 적은 것이라 사람이 고칠 일이 없다 — 커서가 그 줄에 올 때마다 40자 경로가 드러나니
/// 「사진 붙이면 텍스트가 보인다」가 됐다 (2026-09-18 사용자: 「docx 에 사진 넣으면 텍스트 보이던?」).
/// 커서를 그 안에 들이지 않고(`MemoTextEditor`), 지우기는 한 덩이로(`MachineLines.deletion`),
/// 떼기는 사진 자체에서(`NoteView`) — 폰의 글 칸과 같은 규칙이다 (`MachineLines`).
enum MarkdownStyler {
    private typealias Span = MarkdownScanner.Span

    /// 눈에 보이지 않을 만큼 작은 글꼴. 글자를 지우지 않고 감추는 방법이다.
    private static let hiddenSize: CGFloat = 0.01

    /// - Parameter activeLine: 커서가 놓인 줄. 그 줄에서만 기호를 보여준다.
    /// - Parameter scope: 다시 깔 구간. 주면 **그 줄들만** 다시 꾸민다.
    ///
    ///   글 전체를 다시 까는 데는 23k 자에서 0.3초가 든다 — 그 중 0.24초가 스캔이다.
    ///   키를 누를 때마다 그것을 하면 긴 메모에서는 타자가 통째로 밀린다 (측정:
    ///   `LongMemoStylingTests`). 마크다운의 구간은 `.route` 를 뺀 전부가 **한 줄
    ///   안에서 끝나므로**, 고친 줄만 다시 보면 결과가 같다.
    static func apply(
        to storage: NSTextStorage,
        baseFont: NSFont,
        paragraph: NSParagraphStyle?,
        activeLine: NSRange? = nil,
        scope: NSRange? = nil
    ) {
        let text = storage.string
        let source = text as NSString
        let full = NSRange(location: 0, length: source.length)
        let region = region(scope, in: source, full: full)

        storage.beginEditing()
        defer { storage.endEditing() }

        // 매번 바탕부터 다시 깐다. 지운 마커의 흔적이 남지 않게 하는 가장 확실한 길이다.
        storage.setAttributes(baseAttributes(baseFont, paragraph), range: region)

        let allSpans = spans(in: text, region: region, full: full)
        // 가는 길의 절은 카드가 대신 선다 (`RouteCard`). 커서가 그 안에 없으면 통째로 감추고,
        // 그 안의 제목·붙임표에는 꾸밈도 줄머리 표시도 입히지 않는다 — 감춘 줄에 점이 줄지어 서면 안 된다.
        let routeRange = allSpans.first { $0.kind == .route }?.range
        let hiddenRoute = routeRange.flatMap { isOffActiveLine($0, activeLine) ? $0 : nil }
        let spans = allSpans.filter { span in
            guard let hiddenRoute, span.kind != .route else { return true }
            return NSIntersectionRange(span.range, hiddenRoute).length == 0
        }

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
            thinIfTableRule(span.range, in: storage, source: source)
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

        alignTables(in: storage, region: region)
    }

    // MARK: 표 — 글자를 바꾸지 않고 열을 맞춘다

    /// 같은 열의 칸들을 같은 너비로.
    ///
    /// 세로선은 마커라 커서 밖에서는 감춰지는데(0.01pt), 그러면 「구분  금액 / 시급  10,320원」처럼
    /// 열이 흐트러진다. 글자를 탭으로 바꿀 수는 없다(§15.1 — 파일이 정본이다). 대신 **칸의 마지막
    /// 글자에 kern 을 얹는다** — 글자 뒤의 여백만 늘어나므로 파일도 커서 자리도 그대로이고, 다음
    /// 세로선이 그 열의 가장 넓은 칸 뒤에 와서 선다. 너비는 꾸민 뒤의 실제 글꼴로 잰다(머리 칸은
    /// 굵게, 감춘 마커는 0.01pt) — 그려지는 그대로여야 맞는다.
    private static func alignTables(in storage: NSTextStorage, region: NSRange) {
        let source = storage.string as NSString
        var cursor = region.location
        var done: [NSRange] = []
        while cursor < NSMaxRange(region) {
            let line = source.lineRange(for: NSRange(location: cursor, length: 0))
            defer { cursor = NSMaxRange(line) }
            guard let block = MarkdownScanner.tableBlock(containing: line, in: source),
                  !done.contains(block) else { continue }
            done.append(block)
            alignTable(block, in: storage, source: source)
        }
    }

    private static func alignTable(_ block: NSRange, in storage: NSTextStorage, source: NSString) {
        // 줄마다 (칸 구간들). 칸 = 세로선 사이의 글자 전부(양옆 공백 포함).
        var rows: [[NSRange]] = []
        var location = block.location
        while location < NSMaxRange(block) {
            let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(lineRange)
            let line = source.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let pipes = MarkdownScanner.tablePipes(in: line)
            guard pipes.count >= 2 else { continue }
            rows.append(zip(pipes, pipes.dropFirst()).map { a, b in
                NSRange(location: lineRange.location + a + 1, length: b - a - 1)
            })
        }
        guard rows.count >= 2 else { return }
        let columns = rows.map(\.count).max() ?? 0
        guard columns > 0 else { return }

        func width(_ range: NSRange) -> CGFloat {
            guard range.length > 0 else { return 0 }
            return storage.attributedSubstring(from: range).size().width
        }
        var widest = [CGFloat](repeating: 0, count: columns)
        let widths = rows.map { $0.map(width) }
        for row in widths { for (c, w) in row.enumerated() { widest[c] = max(widest[c], w) } }

        // 맞춘 표가 종이 폭을 넘으면 줄이 접혀 도리어 못 읽는다 — 그때는 맞추지 않고 둔다 (좁은 종이).
        // 폭은 **텍스트 뷰의 실제 폭**으로 잰다. 컨테이너의 size 는 첫 배치 전에 천만 pt 라, 그것으로
        // 재면 긴 칸 하나가 다른 줄의 세로선을 수천 pt 밀어 혼자 다음 줄에 떨어뜨린다 (2026-09-18 재현).
        if let textView = storage.layoutManagers.first?.firstTextView,
           let container = textView.textContainer {
            let available = textView.bounds.width - textView.textContainerInset.width * 2 - container.lineFragmentPadding * 2
            let pipeWidth = width(NSRange(location: block.location, length: 1))
            let total = widest.reduce(0, +) + CGFloat(columns + 1) * pipeWidth
            // 폭을 아직 모르는 첫 깔기(bounds 0)도 맞추지 않는다 — 폭이 정해지면 편집기가 다시 깐다
            // (`MemoTextEditor.Coordinator.watch`).
            guard available > 0, total <= available else { return }
        } else {
            return   // 배치가 없는 저장소(미리보기 문자열)는 폭을 모른다 — 맞추지 않는다.
        }

        for (row, cells) in zip(widths, rows) {
            for (c, cell) in cells.enumerated() {
                let pad = widest[c] - row[c]
                // 빈 칸이면 앞의 세로선에 얹는다 — 얹을 글자가 없다.
                let target = cell.length > 0 ? NSRange(location: NSMaxRange(cell) - 1, length: 1)
                                             : NSRange(location: cell.location - 1, length: 1)
                guard pad > 0.5, target.location >= 0, NSMaxRange(target) <= storage.length else { continue }
                storage.addAttribute(.kern, value: pad, range: target)
            }
        }
    }

    // MARK: 고친 줄만 다시 깔기

    /// 실제로 다시 깔 구간 — 언제나 **줄 경계까지** 넓힌다.
    ///
    /// 반 줄만 받으면 스캐너가 다른 것을 본다 (`## 제목` 의 `# 제목` 은 다른 제목이다).
    /// 「가는 길」 절은 여러 줄이 한 덩이라 한 줄만 보고는 판단할 수 없으므로, 그 절을
    /// 가진 메모에서는 통째로 다시 깐다 — 기계가 적는 절이라 드물고, 드문 쪽이 느린 것이 낫다.
    private static func region(_ scope: NSRange?, in source: NSString, full: NSRange) -> NSRange {
        guard let scope, scope.location >= 0, NSMaxRange(scope) <= full.length else { return full }
        guard source.range(of: RouteNote.heading).location == NSNotFound else { return full }
        let lines = source.lineRange(for: scope)
        // 표는 열 너비를 표 전체가 함께 정한다 — 한 줄을 고쳤어도 그 표를 통째로.
        return MarkdownScanner.tableBlock(containing: lines, in: source) ?? lines
    }

    /// 구간 안의 꾸밈 구간들. 좁은 구간이면 **그만큼만 스캔한다** — 여기가 비용의 8할이다.
    private static func spans(in text: String, region: NSRange, full: NSRange) -> [Span] {
        guard !NSEqualRanges(region, full) else { return MarkdownScanner.spans(in: text) }
        let slice = (text as NSString).substring(with: region)
        return MarkdownScanner.spans(in: slice).map {
            Span(
                range: NSRange(location: $0.range.location + region.location, length: $0.range.length),
                kind: $0.kind
            )
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
    /// 하면 된다. 여기서도 글자는 지우지 않는다 (D4) — 커서가 그 줄에 와도
    /// 감춘 채인 것까지 메모 창과 같다.
    static func hideImageReferences(
        to storage: NSTextStorage,
        baseFont: NSFont,
        paragraph: NSParagraphStyle?
    ) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.setAttributes(baseAttributes(baseFont, paragraph), range: full)
        for span in MarkdownScanner.spans(in: text) {
            guard case .image = span.kind else { continue }
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
        // 사진 참조는 커서 줄에서도 — 사람이 고칠 글자가 아니다.
        case .image: true
        case .syntax, .route: isOffActiveLine(span.range, activeLine)
        default: false
        }
    }

    /// 표의 `| --- |` 줄 — 글자를 감춰도 줄 높이는 괘선 한 칸(`linePitch`)이라 표 머리 아래에 빈 줄이
    /// 선다. 그 줄의 문단만 얇게 — 머리와 몸 사이의 얇은 틈이 되어 오히려 표처럼 읽힌다.
    private static func thinIfTableRule(_ range: NSRange, in storage: NSTextStorage, source: NSString) {
        let line = source.lineRange(for: range)
        guard line.location == range.location,
              MarkdownScanner.isTableRule(source.substring(with: line).trimmingCharacters(in: .newlines))
        else { return }
        let thin = (storage.attribute(.paragraphStyle, at: line.location, effectiveRange: nil) as? NSParagraphStyle)?
            .mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        thin.minimumLineHeight = 6
        thin.maximumLineHeight = 6
        storage.addAttribute(.paragraphStyle, value: thin, range: line)
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
                .foregroundColor: Paper.linkNSColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: destination,
                .cursor: NSCursor.pointingHand,
            ], range: range)

        case .image:
            // 실제 그림은 본문 아래에 붙는다. 참조는 언제나 감춘다(`shouldHide`) — 꾸밈은 없다.
            break

        case .route:
            // 커서가 들어와 보일 때는 그냥 글이다 — 꾸밈은 그 안의 제목·붙임표가 입는다.
            break

        case .tablePipe:
            // 흐리되 크기는 그대로 — 감추면 커서가 든 줄만 세로선 너비만큼 밀려 열이 흔들린다.
            storage.addAttribute(.foregroundColor, value: Paper.inkNSColor.withAlphaComponent(0.16), range: range)

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
