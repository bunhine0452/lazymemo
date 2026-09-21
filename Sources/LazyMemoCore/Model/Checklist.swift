import Foundation

/// 체크상자 줄을 **글로** 다루는 길 — 위젯의 체크상자가 두드리는 문.
///
/// 편집기는 커서 자리로 줄을 찾지만(`ListEditing.toggleCheckbox(inLineContaining:)`), 위젯은
/// 그려진 뒤 한참 있다 눌리고 그 사이 다른 기기가 메모를 고쳤을 수 있다. 자리는 어긋나도 글은
/// 남는다 — 「우유」 줄이 아직 있으면 그 줄을 뒤집고, 없어졌으면 아무것도 하지 않는다. 엉뚱한
/// 줄을 뒤집는 것보다 아무것도 안 하는 편이 낫다.
public enum Checklist {
    /// 체크상자 줄 하나 — 상자 뒤의 글(양끝 빈칸을 뗀 것)과 체크 여부.
    public struct Line: Equatable, Hashable, Sendable {
        public let text: String
        public let done: Bool

        public init(text: String, done: Bool) {
            self.text = text
            self.done = done
        }
    }

    /// 본문의 체크상자 줄들 — 줄 차례대로. 상자가 없는 메모는 빈 배열.
    public static func lines(in body: String) -> [Line] {
        let source = body as NSString
        return MarkdownScanner.spans(in: body).compactMap { span in
            guard case .checkbox(let done) = span.kind else { return nil }
            return Line(text: label(after: span.range, in: source), done: done)
        }
    }

    /// `text` 를 든 첫 체크상자 줄(체크 여부가 `done` 인 것)을 뒤집는 바꿈 — 괄호 안 한 글자.
    /// 그런 줄이 없으면 `nil`: 이미 체크됐거나, 글이 바뀌었거나, 줄이 지워졌다.
    public static func toggle(_ text: String, done: Bool, in body: String) -> ListEditing.Edit? {
        let source = body as NSString
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for span in MarkdownScanner.spans(in: body) {
            guard case .checkbox(let state) = span.kind, state == done,
                  label(after: span.range, in: source) == wanted
            else { continue }
            return ListEditing.toggleCheckbox(inLineContaining: span.range.location, in: body)
        }
        return nil
    }

    /// 바꿈을 글에 가한다 — 편집기 밖에서 파일에 되쓸 때.
    public static func applying(_ edit: ListEditing.Edit, to body: String) -> String {
        (body as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
    }

    /// 상자 머리(`- [ ] `) 뒤부터 줄 끝까지.
    private static func label(after marker: NSRange, in source: NSString) -> String {
        let line = source.lineRange(for: marker)
        let start = NSMaxRange(marker)
        let rest = NSRange(location: start, length: max(0, NSMaxRange(line) - start))
        return source.substring(with: rest).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
