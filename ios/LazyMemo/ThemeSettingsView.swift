import LazyMemoCore
import SwiftUI

/// 「테마」 — 종이를 고르고, 원하면 직접 고친다.
///
/// 시트가 반만 올라온다(`.medium`). 고르는 것이 여덟 장이라 화면을 다 덮을
/// 이유가 없고, **반만 올라온 시트는 통째로 엄지 밑에 있다** (MOBILE_DESIGN §3 —
/// "easier and more comfortable to reach a control when it's located in the
/// middle or bottom area"). 견본을 누르면 그 자리에서 뒤의 목록이 바뀐다 —
/// 「적용」 단추가 없는 것이 요점이다.
struct ThemeSettingsView: View {
    let settings: SettingsStore

    @State private var theme = ThemeModel.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThemeCatalog.all, id: \.id) { spec in
                        PhoneSwatch(spec: spec, selected: spec.id == theme.id) {
                            theme.select(spec.id)
                        }
                    }
                }
                custom
                Text("고른 색이 글을 가릴 만큼 흐리면 읽히는 데까지 되끌어 올려 씁니다. 테마는 메모 폴더의 설정에 적힙니다 — 기기 밖의 다른 곳으로는 나가지 않습니다")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Paper.surface)
        .navigationTitle("테마")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { theme.attach(settings: settings) }
    }

    /// 직접 고르기. 글자 크기는 없다 — 폰의 글자는 전부 텍스트 스타일이라
    /// 크기는 시스템의 Dynamic Type 이 정한다 (MOBILE_DESIGN §10).
    private var custom: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("직접 고르기")
                .font(.headline)
            ColorPicker("강조색", selection: accentBinding, supportsOpacity: false)
            ColorPicker("종이에 스미는 색", selection: tintBinding, supportsOpacity: false)
            Toggle("종이 결", isOn: textureBinding)
            Button("기본으로") { theme.resetCustom() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(theme.overrides.isEmpty)
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    private var variant: ThemeVariant { theme.spec.variant(dark: colorScheme == .dark) }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { variant.accent.color },
            set: { next in theme.customize { $0.accent = next.themeRGB } }
        )
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { (theme.overrides.paperTint ?? variant.surface).color },
            set: { next in theme.customize { $0.paperTint = next.themeRGB } }
        )
    }

    private var textureBinding: Binding<Bool> {
        Binding(
            get: { theme.resolved.paperTexture },
            set: { next in theme.customize { $0.paperTexture = next ? nil : false } }
        )
    }
}

/// 종이 한 장의 견본 — 과녁은 44 (HIG). 색 동그라미가 아니라 **작은 종이**다.
private struct PhoneSwatch: View {
    let spec: ThemeSpec
    let selected: Bool
    let choose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var variant: ThemeVariant { spec.variant(dark: colorScheme == .dark) }

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 6) {
                paper
                Text(spec.name)
                    .font(.caption)
                    .foregroundStyle(selected ? Theme.accentInk : Color.secondary)
                    .lineLimit(1)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(spec.name))
        .accessibilityHint(Text(spec.blurb))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var paper: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(variant.surface.color)
            .frame(height: 64)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(variant.ink.color).frame(width: 44, height: 4)
                    Capsule().fill(variant.secondaryInk.color).frame(width: 30, height: 4)
                }
                .padding(11)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle().fill(variant.accent.color).frame(width: 13, height: 13).padding(8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.accentInk : variant.ink.color.opacity(0.18),
                        lineWidth: selected ? 2.5 : 0.75
                    )
            }
    }
}

extension Color {
    /// SwiftUI 의 색을 테마의 숫자로.
    var themeRGB: ThemeRGB {
        let ui = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return .black }
        return ThemeRGB(Double(red), Double(green), Double(blue))
    }
}
