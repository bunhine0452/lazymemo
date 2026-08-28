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
    var font: NSFont = .systemFont(ofSize: 14)
    var insets: NSSize = NSSize(width: 14, height: 6)
    var placeholder: String
    var onEdit: (String) -> Void = { _ in }
    var onCommand: (Selector) -> Bool = { _ in false }

    @Environment(\.rendersStatically) private var rendersStatically

    var body: some View {
        ZStack(alignment: .topLeading) {
            if rendersStatically {
                Text(text)
                    .font(Font(font))
                    .lineSpacing(Theme.bodyLineSpacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, insets.width + 5)
                    .padding(.vertical, insets.height + 1)
            } else {
                MemoTextEditor(
                    text: $text, font: font, insets: insets,
                    onEdit: onEdit, onCommand: onCommand
                )
            }

            if text.isEmpty {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, insets.width + 5)
                    .padding(.vertical, insets.height + 1)
                    .allowsHitTesting(false)
            }
        }
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
