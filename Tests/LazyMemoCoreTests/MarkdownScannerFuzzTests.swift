import Foundation
import Testing
@testable import LazyMemoCore

/// 마커는 ASCII 기호다 — `.syntax` 구간에 한글이 들어 있으면 편집기가 그 글자를 감추거나 줄인다.
/// 사람이 칠 법한 한글·기호 섞인 글을 무작위로 지어 그런 일이 없는지 잰다 (2026-09-18 「한글이 가끔 안 보인다」).
@Suite("MarkdownScanner — 마커에 한글이 들지 않는다")
struct MarkdownScannerFuzzTests {
    @Test("무작위 글 2000줄에서 .syntax 구간은 기호와 공백뿐이다")
    func syntaxNeverSwallowsHangul() {
        let pieces = ["안녕", "메모", "치과", "3시", "**", "*", "_", "__", "`", "~~", "[", "]", "(", ")", "https://a.b/c", "#", "##", "- ", "- [ ] ", "- [x] ", "> ", "!", "![", "](", " ", "  ", "·", "—", "가나다", "ㅋㅋ", "한글 문장입니다", "@강남역", "12,000원", "|", "| --- |"]
        var seed: UInt64 = 42
        func next() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int(seed >> 33) }
        var offenders: [String] = []
        for _ in 0..<2000 {
            let count = 1 + next() % 8
            let line = (0..<count).map { _ in pieces[next() % pieces.count] }.joined()
            let ns = line as NSString
            let spans = MarkdownScanner.spans(in: line)
            // 사진 참조는 통째로 감춰지는 것이 규칙이라(카드가 대신 선다) 그 안의 글은 예외다.
            let images = spans.compactMap { span -> NSRange? in
                if case .image = span.kind { return span.range }
                return nil
            }
            for span in spans where span.kind == .syntax
                && !images.contains(where: { NSIntersectionRange($0, span.range).length == span.range.length }) {
                let marker = ns.substring(with: span.range)
                if marker.unicodeScalars.contains(where: { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }) {
                    offenders.append("«\(line)» → «\(marker)»")
                }
            }
        }
        #expect(offenders.isEmpty, "\(offenders.prefix(10))")
    }
}
