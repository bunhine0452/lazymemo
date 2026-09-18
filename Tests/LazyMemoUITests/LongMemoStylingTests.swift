import AppKit
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 긴 메모에서 글쓰기가 느려지지 않는지 (설계문서 §11 성능 예산).
///
/// 꾸밈은 **키를 누를 때마다** 다시 깔린다. 2만 자 메모를 붙여 넣은 사람이 그 위에서
/// 한 글자 칠 때마다 한 프레임(16ms)을 넘기면 그때부터 타자가 밀린다 — 「대용량
/// 메모를 붙여 넣어도 편하게」의 정반대다. 재 보니 전체를 다시 까는 데 **0.30초**,
/// 그 중 0.24초가 스캔이었다. 그래서 고친 줄만 다시 깐다 (`MarkdownStyler.apply(scope:)`).
///
/// 시간을 재는 시험은 기계 사정에 흔들린다 — 그래서 한 프레임(16ms)이라는 **넉넉한**
/// 천장만 본다. 전체를 다시 까는 길로 되돌아가면 그 천장을 20배로 넘으므로 반드시 걸린다.
@MainActor
@Suite("긴 메모 — 꾸밈 비용")
struct LongMemoStylingTests {
    /// 2만 자 남짓의 실제 메모 모양 — 제목·글줄·목록·인용이 섞인다.
    static func longBody(paragraphs: Int = 200) -> String {
        var lines: [String] = []
        for index in 0..<paragraphs {
            lines.append("## 장 \(index)")
            lines.append("이것은 긴 메모의 한 문단이다. 붙여 넣은 글은 대개 이렇게 길고, **굵은 글자**와 [링크](https://example.com/\(index)) 가 섞인다.")
            lines.append("- [ ] 할 일 \(index)")
            lines.append("> 인용 \(index)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private let font = NSFont.systemFont(ofSize: 13)

    @Test("고친 줄만 다시 까는 데 한 프레임을 넘기지 않는다")
    func scopedRestyleFitsInAFrame() {
        let body = Self.longBody()
        let storage = NSTextStorage(string: body)
        MarkdownStyler.apply(to: storage, baseFont: font, paragraph: nil, activeLine: nil)

        let line = (body as NSString).lineRange(for: NSRange(location: 12_000, length: 0))
        let clock = ContinuousClock()
        let each = clock.measure {
            for _ in 0..<10 {
                MarkdownStyler.apply(
                    to: storage, baseFont: font, paragraph: nil, activeLine: line, scope: line
                )
            }
        } / 10
        print("길이=\(body.count)자 · 한 줄 다시 깔기 \(each)")
        #expect(each < .milliseconds(16), "한 프레임 안에 끝나야 타자가 안 밀린다 — 실제 \(each)")
    }

    @Test("좁게 깐 결과가 전부 깐 결과와 같다 — 빨라지자고 다른 것을 그리면 안 된다")
    func scopedMatchesFull() {
        let body = Self.longBody(paragraphs: 12)
        let line = (body as NSString).lineRange(for: NSRange(location: 200, length: 0))

        let whole = NSTextStorage(string: body)
        MarkdownStyler.apply(to: whole, baseFont: font, paragraph: nil, activeLine: line)

        let scoped = NSTextStorage(string: body)
        MarkdownStyler.apply(to: scoped, baseFont: font, paragraph: nil, activeLine: nil)
        MarkdownStyler.apply(to: scoped, baseFont: font, paragraph: nil, activeLine: line, scope: line)

        #expect(scoped.isEqual(to: whole))
    }

    @Test("「가는 길」 절이 있으면 통째로 다시 깐다 — 여러 줄이 한 덩이라 한 줄만 보면 틀린다")
    func fallsBackWhenRouteSectionIsThere() {
        let body = "밥약속\n\n" + RouteNote.heading + "\n망원 → 강남 · 21분\n- 걷기 2분"
        let line = (body as NSString).lineRange(for: NSRange(location: 0, length: 0))

        let whole = NSTextStorage(string: body)
        MarkdownStyler.apply(to: whole, baseFont: font, paragraph: nil, activeLine: line)

        let scoped = NSTextStorage(string: body)
        MarkdownStyler.apply(to: scoped, baseFont: font, paragraph: nil, activeLine: line, scope: line)

        #expect(scoped.isEqual(to: whole))
    }

    @Test("커서가 들고 난 두 줄은 함께 깔리되, 멀면 사이는 건드리지 않는다")
    func regionsKeepBothLinesApart() {
        let near = MemoTextEditor.Coordinator.regions(
            NSRange(location: 100, length: 4),
            leaving: NSRange(location: 90, length: 12),
            entering: NSRange(location: 100, length: 10)
        )
        #expect(near.count == 1)

        let far = MemoTextEditor.Coordinator.regions(
            NSRange(location: 9_000, length: 2),
            leaving: NSRange(location: 20, length: 10),
            entering: NSRange(location: 9_000, length: 30)
        )
        #expect(far.count == 2)
        #expect(far.compactMap { $0 }.reduce(0) { $0 + $1.length } < 100)

        // 구간을 안 주면 「전부」다.
        #expect(MemoTextEditor.Coordinator.regions(nil, leaving: nil, entering: nil) == [nil])
    }
}
