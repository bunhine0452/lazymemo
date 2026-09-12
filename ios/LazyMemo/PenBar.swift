import LazyMemoCore
import SwiftUI

/// 화면 바닥의 펜 — 칩 줄 · 되돌리기 띠 · 펜 줄 (MOBILE_DESIGN §3).
///
/// 바탕은 종이다. 탭바는 시스템 유리지만 **적는 면은 종이여야 한다** (§14.5).
struct PenBar: View {
    let pen: PenModel
    let undo: UndoModel
    let usingCloud: Bool
    var fixing = false
    /// 「위치를 못 잡았습니다」 — 칩 자리에 한 번.
    var hereTrouble: String?
    var onHere: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !usingCloud {
                band("이 기기에만 남습니다 · iCloud 가 꺼져 있습니다", tint: Theme.highlightInk)
                    .accessibilityIdentifier("local-band")
            }
            if let offer = undo.offer {
                HStack {
                    Text(offer.message).font(.subheadline)
                    Spacer()
                    Button("되돌리기") { Task { await undo.take() } }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("undo")
                }
                .foregroundStyle(Theme.accentInk)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(Theme.accentInk.opacity(0.09))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            chips
            penRow
        }
        .background(Paper.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Paper.ink.opacity(0.12)).frame(height: 0.5)
        }
        .animation(.snappy(duration: 0.2), value: undo.offer?.id)
        .task {
            // 켜면 펜이다 — 키보드가 이미 올라와 있다.
            try? await Task.sleep(for: .milliseconds(80))
            focused = true
        }
        .onChange(of: pen.focusRequest) { _, _ in focused = true }
    }

    // MARK: 칩 — 누르기 전에 무엇을 읽었는지 보인다

    @ViewBuilder
    private var chips: some View {
        let date = pen.dateChip
        let place = pen.placeChip
        let every = pen.everyChip
        if date != nil || place != nil || every != nil || hereTrouble != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let hereTrouble, pen.here == nil {
                        Text(hereTrouble)
                            .font(.footnote)
                            .foregroundStyle(Paper.fadedInk)
                            .frame(minHeight: 32)
                            .accessibilityIdentifier("here-trouble")
                    }
                    if let date {
                        chip(date, on: pen.readsDate, hint: "누르면 날짜로 읽지 않습니다") { pen.readsDate.toggle() }
                            .accessibilityIdentifier("chip-date")
                    }
                    if let every {
                        chip(every, on: pen.readsDate, hint: "누르면 되풀이로 읽지 않습니다") { pen.readsDate.toggle() }
                    }
                    if let place {
                        chip(place, on: pen.readsPlace || pen.here != nil, hint: "누르면 장소로 읽지 않습니다") {
                            if pen.here != nil { pen.here = nil } else { pen.readsPlace.toggle() }
                        }
                        .accessibilityIdentifier("chip-place")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }

    private func chip(_ label: String, on: Bool, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(on ? Theme.highlightInk : Paper.fadedInk)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: Theme.chipRadius)
                        .fill(on ? Theme.highlightWash : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.chipRadius)
                        .stroke(on ? .clear : Paper.fadedInk.opacity(0.5), lineWidth: 1)
                )
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    // MARK: 펜 줄 — 핀 · 글 칸 · 남기기

    private var penRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: onHere) {
                if fixing {
                    ProgressView().frame(width: 44, height: 44)
                } else {
                    Image(systemName: "mappin")
                        .font(.system(size: 18))
                        .foregroundStyle(pen.here == nil ? Theme.accentInk.opacity(0.4) : Theme.accentInk)
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
            .disabled(fixing)
            .accessibilityLabel("지금 여기")
            .accessibilityHint("이 자리의 주소를 메모에 붙입니다")
            .accessibilityIdentifier("here")

            TextField(pen.prompt, text: Bindable(pen).text, axis: .vertical)
                .font(.title2.weight(.light))
                .foregroundStyle(Paper.ink)
                .lineLimit(1...5)
                .focused($focused)
                .frame(minHeight: 44)
                .accessibilityLabel("적기")
                .accessibilityIdentifier("capture")

            Button(action: { Task { await pen.leave() } }) {
                Text(pen.leaveLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(!pen.canLeave)
            .opacity(pen.canLeave ? 1 : 0.45)
            .accessibilityIdentifier("leave")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func band(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1))
    }
}
