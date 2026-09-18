import AppKit
import SwiftUI
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 「메모의 한글이 가끔 안 보인다」(사용자, 2026-09-18). 감추기는 글꼴을 0.01pt 로 줄이는 것이라,
/// 감출 것이 아닌 글자에 그 글꼴이 남으면 글자가 사라진다. 한글은 조합(marked text)을 거치므로
/// 라틴과 다른 길을 탄다 — 여기서는 사람이 치는 차례를 그대로 흉내 내고, 매 걸음마다 **마커가 아닌
/// 글자가 전부 보이는지** 잰다.
@MainActor
@Suite("종이 — 한글을 쳐도 글자가 사라지지 않는다")
struct KoreanTypingVisibilityTests {
    private final class Box { var text = "" }

    private func makeEditor(_ initial: String) -> (MemoNSTextView, MemoTextEditor.Coordinator, NSWindow, Box) {
        let font = NSFont.systemFont(ofSize: Paper.bodySize)
        let textView = MemoTextEditor.makeTextView(
            font: font, insets: NSSize(width: Theme.loose, height: Theme.loose), linePitch: Paper.linePitch
        )
        let box = Box()
        box.text = initial
        let coordinator = MemoTextEditor.Coordinator(
            text: Binding(get: { box.text }, set: { box.text = $0 }),
            onEdit: { _ in }, onCommand: { _, _ in false }
        )
        coordinator.stylesMarkdown = true
        coordinator.baseFont = font
        coordinator.paragraph = textView.defaultParagraphStyle
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.deletesPhotoReferencesWhole = true
        textView.onFocusChange = { [weak coordinator] view, focused in coordinator?.focusChanged(view, focused: focused) }
        textView.string = initial
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        coordinator.restyle(textView)
        return (textView, coordinator, window, box)
    }

    /// 조합 — 자모를 하나씩 얹다가 확정한다. `steps` 는 조합 중간 모양들, `final` 은 확정 글자.
    private func compose(_ textView: NSTextView, _ steps: [String], final: String) {
        for step in steps {
            let replacement = textView.hasMarkedText() ? textView.markedRange() : textView.selectedRange()
            textView.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0), replacementRange: replacement)
        }
        textView.insertText(final, replacementRange: textView.markedRange())
    }

    /// 마커가 아닌데 감춰진 글자들 — 있으면 결함이다. 어디가 그런지 문맥과 함께 돌려준다.
    private func invisible(in textView: NSTextView) -> [String] {
        guard let storage = textView.textStorage else { return ["storage 없음"] }
        let text = storage.string
        let source = text as NSString
        var allowed = NSMutableIndexSet()
        for span in MarkdownScanner.spans(in: text) {
            switch span.kind {
            case .syntax, .image, .route, .bullet, .quote, .checkbox: allowed.add(in: span.range)
            default: break
            }
        }
        var bad: [String] = []
        storage.enumerateAttribute(.font, in: NSRange(location: 0, length: source.length)) { value, range, _ in
            guard let font = value as? NSFont, font.pointSize < 1 else { return }
            for i in range.location..<NSMaxRange(range) where !allowed.contains(i) {
                let ch = source.substring(with: NSRange(location: i, length: 1))
                guard ch != "\n" else { continue }
                let line = source.lineRange(for: NSRange(location: i, length: 0))
                bad.append("\(i) «\(ch)» in «\(source.substring(with: line).trimmingCharacters(in: .newlines))»")
            }
        }
        return bad
    }

    @Test("굵게 마커 뒤에서 조합한 한글이 보인다")
    func afterBoldMarkers() {
        let (textView, _, window, _) = makeEditor("**굵게**")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 8, length: 0))
        textView.insertText(" ", replacementRange: textView.selectedRange())
        compose(textView, ["ㅎ", "하", "한"], final: "한")
        compose(textView, ["ㄱ", "그", "글"], final: "글")
        #expect(textView.string == "**굵게** 한글")
        #expect(invisible(in: textView).isEmpty, "\(invisible(in: textView))")
    }

    @Test("제목 줄에서 Return 뒤에 조합한 한글이 보인다")
    func newLineAfterHeading() {
        let (textView, _, window, _) = makeEditor("# 제목")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        textView.insertText("\n", replacementRange: textView.selectedRange())
        compose(textView, ["ㅁ", "메", "멤", "메모"], final: "메모")
        #expect(textView.string == "# 제목\n메모")
        #expect(invisible(in: textView).isEmpty, "\(invisible(in: textView))")
    }

    @Test("사진 참조 줄 뒤에서 조합한 한글이 보인다")
    func afterPhotoReference() {
        let (textView, _, window, _) = makeEditor("메모\n![](attachments/photo.png)\n")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        compose(textView, ["ㅅ", "사", "사ㅈ", "사지", "사진"], final: "사진")
        compose(textView, ["ㅇ", "아", "아ㄹ", "아래", "아래"], final: " 아래")
        #expect(invisible(in: textView).isEmpty, "\(invisible(in: textView))")
    }

    @Test("체크 줄과 링크 줄을 오가며 조합해도 보인다")
    func acrossMarkedLines() {
        let (textView, _, window, _) = makeEditor("- [ ] 우유\n[이름](https://example.com)\n끝")
        defer { window.orderOut(nil) }
        let source = textView.string as NSString
        // 체크 줄 끝에서
        textView.setSelectedRange(NSRange(location: source.range(of: "우유").location + 2, length: 0))
        compose(textView, ["ㅇ", "와"], final: " 와")
        #expect(invisible(in: textView).isEmpty, "체크 줄: \(invisible(in: textView))")
        // 링크 줄 끝으로 가서
        let linkEnd = (textView.string as NSString).range(of: ")\n").location + 1
        textView.setSelectedRange(NSRange(location: linkEnd, length: 0))
        compose(textView, ["ㄷ", "뒤"], final: " 뒤")
        #expect(invisible(in: textView).isEmpty, "링크 줄: \(invisible(in: textView))")
        // 마지막 줄로 가서
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        compose(textView, ["ㅇ", "이", "입", "이ㄴ"], final: "이"); compose(textView, ["ㄷ", "다"], final: "다")
        #expect(invisible(in: textView).isEmpty, "끝 줄: \(invisible(in: textView))")
        // 되돌아가서 굵게 안에 넣기
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.insertText("**", replacementRange: textView.selectedRange())
        compose(textView, ["ㅈ", "중"], final: "중")
        textView.insertText("**", replacementRange: textView.selectedRange())
        #expect(invisible(in: textView).isEmpty, "굵게 안: \(invisible(in: textView))")
    }

    @Test("조합 도중 파일이 되밀려도, 끝난 뒤 글자가 보인다")
    func externalSyncDuringComposition() {
        let (textView, coordinator, window, box) = makeEditor("첫 줄")
        defer { window.orderOut(nil) }
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        textView.insertText("\n", replacementRange: textView.selectedRange())
        compose(textView, ["ㅎ", "하"], final: "")   // 조합만 시작
        textView.setMarkedText("한", selectedRange: NSRange(location: 1, length: 0), replacementRange: textView.selectedRange())
        // 파일 감시가 같은 글(끝 줄바꿈만 다른)을 되민다 — 조합 중이라 거절돼야 한다
        _ = MemoTextSync.apply(box.text + "\n", to: textView)
        textView.insertText("한", replacementRange: textView.markedRange())
        compose(textView, ["ㄱ", "글"], final: "글")
        if MemoTextSync.apply(textView.string, to: textView) { coordinator.restyle(textView) }
        #expect(invisible(in: textView).isEmpty, "\(invisible(in: textView))")
    }

    @Test("긴 글을 붙인 뒤 여기저기서 조합해도 보인다")
    func afterPasteAndRandomEdits() {
        var lines: [String] = []
        for i in 1...40 { lines.append(i % 5 == 0 ? "## 절 \(i)" : (i % 3 == 0 ? "- [ ] 할 일 \(i) **중요**" : "본문 \(i) 한글 문장입니다.")) }
        let (textView, _, window, _) = makeEditor(lines.joined(separator: "\n"))
        defer { window.orderOut(nil) }
        var seed: UInt64 = 7
        func next() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int(seed >> 33) }
        for _ in 0..<40 {
            let length = (textView.string as NSString).length
            textView.setSelectedRange(NSRange(location: next() % max(1, length), length: 0))
            compose(textView, ["ㅇ", "안", "안ㄴ", "안녀", "안녕"], final: "안녕")
            let bad = invisible(in: textView)
            #expect(bad.isEmpty, "\(bad)")
            if !bad.isEmpty { break }
        }
    }
}

extension KoreanTypingVisibilityTests {
    @Test("블록 구조 줄들 — 어느 줄의 한글도 감춰지지 않는다 (커서 밖에서, 커서 위에서)")
    func blockConstructsStayVisible() {
        let docs = [
            "> 인용한 한글 문장\n다음 줄",
            "# 제목 한글\n## 둘째 제목\n본문",
            "1. 첫째 항목\n2. 둘째 항목\n- 점 항목\n  - 안긴 항목",
            "- [x] 끝난 일 한글\n- [ ] 남은 일",
            "```\n코드 한글\n```\n뒤",
            "---\n구분선 아래 한글\n***",
            "| 구분 | 금액 |\n| --- | --- |\n| 시급 | 만 원 |\n표 아래 한글",
            "링크 [이름](https://a.b) 뒤 한글 *기울임* **굵게** ~~취소~~ `코드` 끝",
            "## 가는 길\n강남역에서 2호선 · 14분\n- 18:12 출발\n\n그 아래 내 메모 한글",
            "사진\n![설명](attachments/a.png)\n사진 아래 한글",
            "@강남역 12,000원 3시 #병원 한글",
            "첫 줄\n\n\n빈 줄 여럿 뒤 한글\n",
        ]
        for doc in docs {
            let (textView, coordinator, window, _) = makeEditor(doc)
            defer { window.orderOut(nil) }
            var bad = invisible(in: textView)
            #expect(bad.isEmpty, "포커스 있음 «\(doc.prefix(30))»: \(bad)")
            // 커서를 줄마다 옮겨 본다
            let source = textView.string as NSString
            var location = 0
            while location < source.length {
                textView.setSelectedRange(NSRange(location: location, length: 0))
                bad = invisible(in: textView)
                #expect(bad.isEmpty, "커서 \(location) «\(doc.prefix(30))»: \(bad)")
                location = NSMaxRange(source.lineRange(for: NSRange(location: location, length: 0)))
                if location >= source.length { break }
            }
            // 포커스를 잃은 종이 — 바탕화면에 눕힌 상태
            window.makeFirstResponder(nil)
            coordinator.focusChanged(textView, focused: false)
            bad = invisible(in: textView)
            #expect(bad.isEmpty, "포커스 없음 «\(doc.prefix(30))»: \(bad)")
            // 파일이 되밀린 뒤(끝 줄바꿈이 떨어져 돌아온 본문)
            let trimmed = doc.hasSuffix("\n") ? String(doc.dropLast()) : doc + "\n"
            if MemoTextSync.apply(trimmed, to: textView) { coordinator.restyle(textView) }
            bad = invisible(in: textView)
            #expect(bad.isEmpty, "되밀린 뒤 «\(doc.prefix(30))»: \(bad)")
        }
    }
}
