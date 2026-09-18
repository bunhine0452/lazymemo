import AppKit
import SwiftUI

/// 글 쓰는 자리. 안내 문구와 정적 렌더 대체를 함께 맡는다.
///
/// `ImageRenderer` 는 `NSViewRepresentable` 을 그리지 못하고 금지 표시를 남긴다.
/// 미리보기(`LAZYMEMO_RENDER`)에서 그 자리를 같은 글꼴·여백의 `Text` 로 바꾸면
/// 배치와 색을 정확히 확인할 수 있다. 대체 여부를 환경값으로 흘려보내는 이유는
/// 뷰마다 미리보기용 인자를 달고 다니지 않기 위해서다.
struct MemoTextArea: View {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: Paper.bodySize)
    var insets: NSSize = NSSize(width: 14, height: 6)
    var linePitch: CGFloat?
    var stylesMarkdown = false
    /// 꾸밈은 끄되 사진 참조만 감출지 (`MemoTextEditor`).
    var hidesImageReferences = false
    var onPasteImage: ((Data, String) -> String?)?
    var onPasteLink: ((URL) -> String?)?
    var onDelete: (() -> Void)?
    var movesWindow = false
    var blursOnEscape = false
    var onEscape: (() -> Void)?
    var placeholder: String
    var onEdit: (String) -> Void = { _ in }
    var onCommand: (Selector, NSTextView) -> Bool = { _, _ in false }
    var onCommandReturn: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        ZStack(alignment: .topLeading) {
            if rendersStatically {
                staticText
                    .font(Font(font))
                    // 괘선 간격을 그대로 흉내 낸다. 미리보기와 실제 화면의
                    // 줄 위치가 어긋나면 괘선을 맞출 수가 없다.
                    .lineSpacing(linePitch.map { $0 - font.ascender + font.descender } ?? Theme.bodyLineSpacing)
                    .foregroundStyle(Paper.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, insets.width + 5)
                    .padding(.vertical, insets.height + 1)
            } else {
                MemoTextEditor(
                    text: $text, font: font, insets: insets, linePitch: linePitch,
                    stylesMarkdown: stylesMarkdown, hidesImageReferences: hidesImageReferences,
                    onPasteImage: onPasteImage, onPasteLink: onPasteLink,
                    onDelete: onDelete, movesWindow: movesWindow, blursOnEscape: blursOnEscape,
                    onEscape: onEscape, onEdit: onEdit, onCommand: onCommand,
                    onCommandReturn: onCommandReturn, onHeightChange: onHeightChange
                )
            }

            if text.isEmpty {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundStyle(Paper.ink.opacity(0.28))
                    .padding(.horizontal, insets.width + 5)
                    .padding(.vertical, insets.height + 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension MemoTextArea {
    /// 화면 밖 렌더에서도 **실제 스타일러가 만든 것**을 보여준다.
    ///
    /// 평범한 `Text` 로 대체하면 배치는 확인할 수 있어도 마크다운 꾸밈이
    /// 맞는지는 알 수 없다. 같은 `MarkdownStyler` 를 태워 속성 문자열을 만든 뒤
    /// SwiftUI 로 건네면, 미리보기가 실제 편집기와 같은 것을 그린다.
    fileprivate var staticText: Text {
        guard stylesMarkdown || hidesImageReferences else { return Text(text) }

        let paragraph = NSMutableParagraphStyle()
        if let pitch = linePitch {
            paragraph.minimumLineHeight = pitch
            paragraph.maximumLineHeight = pitch
        }

        let storage = NSTextStorage(string: text)
        guard stylesMarkdown else {
            // 빠른 입력 — 사진 경로만 감춘 채로 보여야 미리보기가 거짓말을 안 한다.
            MarkdownStyler.hideImageReferences(to: storage, baseFont: font, paragraph: paragraph)
            return Text(AttributedString(storage))
        }
        MarkdownStyler.apply(to: storage, baseFont: font, paragraph: paragraph, activeLine: nil)
        // 여백에 직접 그리는 줄머리 표시는 SwiftUI `Text` 가 그리지 못한다.
        // 미리보기에서만 같은 뜻의 글리프로 바꿔 끼운다.
        MarkdownStyler.substituteMarkersForPreview(in: storage, baseFont: font)
        return Text(AttributedString(storage))
    }
}

private struct StaticRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 화면이 아니라 이미지로 그려지는 중인가.
    var rendersStatically: Bool {
        get { self[StaticRenderingKey.self] }
        set { self[StaticRenderingKey.self] = newValue }
    }
}
