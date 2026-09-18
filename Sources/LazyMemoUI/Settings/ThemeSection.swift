import AppKit
import LazyMemoCore
import SwiftUI

/// 설정 창의 「테마」 절 — **견본을 고르고, 원하면 직접 고친다.**
///
/// 값의 주인이 설정 파일 하나뿐이라(다른 절과 달리 시스템에 물을 것이 없다)
/// 사진 한 장(`SettingsState`)을 거치지 않고 `ThemeStore` 를 곧장 본다.
/// 누르는 즉시 바탕화면의 종이가 바뀐다 — 「적용」 단추가 없는 것이 요점이다.
struct ThemeSection: View {
    @Bindable var store: ThemeStore
    @State private var customizing = false

    var body: some View {
        Section {
            swatches
            DisclosureGroup(isExpanded: $customizing) {
                custom
            } label: {
                Text(L("직접 고르기"))
            }
        } header: {
            Text(L("테마"))
        } footer: {
            Text(L("고른 색이 글을 가릴 만큼 흐리면 읽히는 데까지 되끌어 올려 씁니다. 테마는 이 맥에만 남습니다 — 기기 밖으로 나가지 않습니다"))
        }
    }

    // MARK: 견본

    /// 종이 여덟 장을 **한 눈에.** 작게 그린 진짜 종이다 — 색 동그라미를 늘어놓으면
    /// 고르는 사람은 고르고 나서야 종이를 처음 본다.
    ///
    /// 옆으로 미는 줄로 두었더니 여덟 번째가 판 밖에 있었다. 고를 수 있는 것이
    /// 안 보이면 없는 것과 같으므로 넉 줄씩 두 줄로 세운다.
    private var swatches: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.tight), count: 4),
                  spacing: Theme.snug) {
            ForEach(ThemeCatalog.all, id: \.id) { spec in
                ThemeSwatch(spec: spec, selected: spec.id == store.id) {
                    store.select(spec.id)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel(Text(L("테마")))
    }

    // MARK: 직접 고르기

    private var custom: some View {
        VStack(alignment: .leading, spacing: Theme.snug) {
            ColorPicker(L("강조색"), selection: accentBinding, supportsOpacity: false)
            ColorPicker(L("종이에 스미는 색"), selection: tintBinding, supportsOpacity: false)
            Picker(L("글자 크기"), selection: stepBinding) {
                Text(L("작게")).tag(-1)
                Text(L("기본")).tag(0)
                Text(L("크게")).tag(1)
                Text(L("더 크게")).tag(2)
            }
            .pickerStyle(.segmented)
            Toggle(L("종이 결"), isOn: textureBinding)
            HStack {
                Spacer()
                Button(L("기본으로")) { store.resetCustom() }
                    .disabled(store.overrides.isEmpty)
            }
        }
        .padding(.top, 4)
    }

    // MARK: 값 ↔ 조작

    private var variant: ThemeVariant {
        store.spec.variant(dark: NSApp.effectiveAppearance.isDark)
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { variant.accent.color },
            set: { next in store.customize { $0.accent = next.themeRGB } }
        )
    }

    /// 종이에 스미는 색. 아직 아무것도 안 골랐으면 **지금 종이의 색**을 보인다 —
    /// 빈 칸을 보이면 고르는 사람은 무엇에서 출발하는지 모른다.
    private var tintBinding: Binding<Color> {
        Binding(
            get: { (store.overrides.paperTint ?? variant.surface).color },
            set: { next in store.customize { $0.paperTint = next.themeRGB } }
        )
    }

    private var stepBinding: Binding<Int> {
        Binding(
            get: { store.overrides.step },
            set: { next in store.customize { $0.textStep = next == 0 ? nil : next } }
        )
    }

    private var textureBinding: Binding<Bool> {
        Binding(
            get: { store.resolved.paperTexture },
            set: { next in store.customize { $0.paperTexture = next ? nil : false } }
        )
    }
}

/// 종이 한 장의 견본 — 바탕·잉크 두 줄·강조색 점.
private struct ThemeSwatch: View {
    let spec: ThemeSpec
    let selected: Bool
    let choose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var variant: ThemeVariant { spec.variant(dark: colorScheme == .dark) }

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 5) {
                paper
                Text(spec.name)
                    .font(Theme.micro)
                    .foregroundStyle(selected ? Theme.accentInk : Color.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help(spec.name + " — " + spec.blurb)
        .accessibilityLabel(Text(spec.name))
        .accessibilityHint(Text(spec.blurb))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var paper: some View {
        RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
            .fill(variant.surface.color)
            .frame(height: 50)
            .overlay(alignment: .topLeading) { lines }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(variant.accent.color)
                    .frame(width: 11, height: 11)
                    .padding(6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.accentInk : variant.ink.color.opacity(0.18),
                        lineWidth: selected ? 2 : 0.75
                    )
            }
    }

    /// 글 두 줄. 잉크가 이 종이 위에서 어떻게 보이는지가 견본의 요점이다.
    private var lines: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(variant.ink.color).frame(width: 34, height: 3)
            Capsule().fill(variant.secondaryInk.color).frame(width: 24, height: 3)
        }
        .padding(9)
    }
}

extension Color {
    /// SwiftUI 의 색을 테마의 숫자로. 고를 수 없는 색(패턴 따위)이면 검정.
    var themeRGB: ThemeRGB {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return .black }
        return ThemeRGB(
            Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)
        )
    }
}
