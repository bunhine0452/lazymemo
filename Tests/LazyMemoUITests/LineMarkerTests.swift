import AppKit
import Testing
@testable import LazyMemoUI

/// 줄머리 표시와 체크상자 누르기 회귀 테스트.
///
/// 체크상자는 글자가 아니라 **여백에 그리는 그림**이라, 좌표 계산이 조금만
/// 어긋나도 눌러도 아무 일이 일어나지 않는다. 그리고 그 실패는 조용하다 —
/// 빌드도 통과하고 화면도 멀쩡해 보인다. 실제로 만드는 동안 기준선 계산이
/// 두 번 어긋났고, 둘 다 사람이 렌더를 눈으로 봐야만 드러났다.
@MainActor
@Suite("줄머리 표시")
struct LineMarkerTests {
    private static let body = """
        ## 장보기
        - [x] 우유
        - [ ] **계란** 두 판
        - 식빵
        > 세제도 떨어졌음
        """

    private func makeStyledTextView(_ text: String = body) -> MemoNSTextView {
        let font = NSFont.systemFont(ofSize: Paper.bodySize)
        let textView = MemoTextEditor.makeTextView(
            font: font,
            insets: NSSize(width: Theme.loose, height: Theme.loose),
            linePitch: Paper.linePitch
        )
        textView.isVerticallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: 300, height: 260)
        textView.string = text

        if let storage = textView.textStorage {
            MarkdownStyler.apply(
                to: storage, baseFont: font,
                paragraph: textView.defaultParagraphStyle, activeLine: nil
            )
        }
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: 300, height: 260)
            textView.layoutManager?.ensureLayout(for: container)
        }
        return textView
    }

    private func markers(_ textView: MemoNSTextView) -> [(LineMarker, NSRect)] {
        var found: [(LineMarker, NSRect)] = []
        textView.forEachLineMarker { marker, _, frame in found.append((marker, frame)) }
        return found
    }

    @Test("체크상자·글머리 점·인용선이 줄마다 하나씩 잡힌다")
    func findsEveryMarker() {
        let kinds = markers(makeStyledTextView()).map(\.0)
        #expect(kinds == [.checked, .unchecked, .bullet, .quote])
    }

    @Test("표시는 글이 시작되기 전 여백에 있다 — 글자를 가리지 않는다")
    func staysInTheGutter() {
        let textView = makeStyledTextView()
        for (marker, frame) in markers(textView) {
            let box = marker.box(at: frame.minX, centerY: frame.midY, lineHeight: frame.height)
            // 글은 여백(gutter)만큼 들여써 있으므로 그 안에 들어와야 한다.
            #expect(box.maxX <= frame.minX + marker.gutter)
        }
    }

    @Test("표시는 그 줄의 글과 세로로 맞는다")
    func alignsWithItsOwnLine() {
        let textView = makeStyledTextView()
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer
        else { Issue.record("레이아웃 없음"); return }

        textView.forEachLineMarker { _, range, frame in
            let glyphs = layoutManager.glyphRange(
                forCharacterRange: range, actualCharacterRange: nil
            )
            var line = layoutManager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            line.origin.y += textView.textContainerInset.height
            // 표시의 한가운데가 제 줄 상자 안에 있어야 한다.
            #expect(frame.midY > line.minY)
            #expect(frame.midY < line.maxY)
        }
    }

    @Test("체크상자를 누르면 표시가 뒤집힌다 — 글자를 고치게 하지 않는다")
    func togglesOnClick() {
        let textView = makeStyledTextView()
        guard let first = markers(textView).first(where: { $0.0.isCheckbox }) else {
            Issue.record("체크상자를 못 찾았다"); return
        }
        let box = first.0.box(at: first.1.minX, centerY: first.1.midY, lineHeight: first.1.height)

        #expect(textView.toggleCheckbox(at: CGPoint(x: box.midX, y: box.midY)))
        #expect(textView.string.contains("- [ ] 우유"))
        #expect(!textView.string.contains("- [x] 우유"))
    }

    @Test("여백 밖을 누르면 체크상자가 반응하지 않는다")
    func ignoresClicksAwayFromTheBox() {
        let textView = makeStyledTextView()
        let before = textView.string
        #expect(!textView.toggleCheckbox(at: CGPoint(x: 200, y: 120)))
        #expect(textView.string == before)
    }

    @Test("마크다운 원문은 그대로 남는다 — 파일이 정본이다")
    func keepsTheMarkdownIntact() {
        let textView = makeStyledTextView()
        #expect(textView.string == Self.body)
    }
}
