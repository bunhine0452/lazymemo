import LazyMemoCore
import SwiftUI

/// 안내의 그림 — 앱의 진짜 부품을 작게 그린 것. 펜·「지금」 카드·줄·달력·위젯이 본 화면과
/// 같은 색과 모양으로 서서, 안내를 닫았을 때 눈이 이미 아는 것을 만난다.
///
/// 만질 수 없고(`allowsHitTesting(false)`) 소리로도 읽지 않는다 — 그림의 말은 옆의 글이 한다.
/// 글자는 그림으로 굽지 않고 `Text` 로 둔다 — 다크·큰 글자·테마를 그대로 따라간다.
enum TutorialArt {
    case pen, now, gestures, calendar, doors
}

struct TutorialArtView: View {
    let art: TutorialArt

    var body: some View {
        Group {
            switch art {
            case .pen: PenArt()
            case .now: NowArt()
            case .gestures: GestureArt()
            case .calendar: CalendarArt()
            case .doors: DoorsArt()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Paper.ink.opacity(0.07), lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 조각

/// 펜의 칩 — 읽은 것이 단추가 되기 전에 보인다.
private struct ArtChip: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.accentInk.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.chipRadius))
            .lineLimit(1)
    }
}

/// 종이 한 장 — 목록의 줄과 「지금」 카드가 앉는 면.
private struct ArtSheet<Content: View>: View {
    var radius: CGFloat = 14
    var edge: Color = Paper.ink.opacity(0.08)
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(Paper.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(edge, lineWidth: 1))
    }
}

/// 「봤어요」의 동그라미 — 카드 오른쪽.
private struct ArtSeen: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Paper.ink.opacity(0.07), in: Circle())
            Text("봤어요").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 1. 펜

private struct PenArt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ArtChip(text: "9월 22일 (화) 15:00 · 달력으로")
                ArtChip(text: "@강남역")
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentInk.opacity(0.1), in: Circle())
                ArtSheet(radius: Theme.controlRadius, edge: Theme.accentInk.opacity(0.5)) {
                    HStack(spacing: 2) {
                        Text("내일 3시 치과 @강남역")
                            .font(.subheadline)
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                        RoundedRectangle(cornerRadius: 1).fill(Theme.accentInk).frame(width: 2, height: 18)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                }
                Text("달력에 남기기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Theme.accent, in: Capsule())
            }
            HStack(spacing: 8) {
                Text(verbatim: "ㅊㄱ")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Paper.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Paper.surface, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).strokeBorder(Paper.ink.opacity(0.1)))
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Circle().fill(MemoColor.blue.ink).frame(width: 8, height: 8)
                    Text("치과 예약 — 강남역 3번 출구").font(.caption).foregroundStyle(Paper.ink).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 2. 「지금」

private struct NowArt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지금")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            card(reason: "다시 보기 · 오후 2:30", symbol: "bell.fill", title: "회의 전에 물어볼 것", color: .blue)
            card(reason: "오늘 일정 · 오후 3:00", symbol: "calendar", title: "치과 예약 — 강남역 3번 출구", color: .green)
            HStack(spacing: 6) {
                Image(systemName: "bell").font(.caption).foregroundStyle(Theme.accentInk)
                ArtChip(text: "한 시간 뒤")
                ArtChip(text: "내일 아침 9시")
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    private func card(reason: LocalizedStringKey, symbol: String, title: LocalizedStringKey, color: MemoColor) -> some View {
        ArtSheet(edge: Theme.accentInk.opacity(0.3)) {
            HStack(spacing: 10) {
                Capsule().fill(color.ink).frame(width: 3, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Label(reason, systemImage: symbol)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(Theme.accentInk)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Paper.ink).lineLimit(1)
                }
                Spacer(minLength: 4)
                ArtSeen()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 3. 손짓

private struct GestureArt: View {
    var body: some View {
        VStack(spacing: 8) {
            row("장보기 — 우유·계란·두부", color: .yellow, leading: ("pin.fill", "고정"), tint: Theme.accent)
            row("치과 예약 — 강남역 3번 출구", color: .blue, leading: ("arrow.right", "미루기"), tint: Theme.accent)
            row("지난달 회의 메모", color: .gray, trailing: ("trash.fill", "지우기"), tint: .red)
            HStack(spacing: 14) {
                Label("길게 누르면 폴더·달력", systemImage: "hand.tap")
                Label("흔들면 되돌리기", systemImage: "iphone.gen3.radiowaves.left.and.right")
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.top, 2)
        }
    }

    /// 줄 하나 — 밀린 채 뒤의 단추가 보인다.
    private func row(
        _ title: LocalizedStringKey, color: MemoColor,
        leading: (String, LocalizedStringKey)? = nil, trailing: (String, LocalizedStringKey)? = nil, tint: Color
    ) -> some View {
        let reveal: CGFloat = 76
        return ZStack(alignment: leading != nil ? .leading : .trailing) {
            if let (symbol, label) = leading ?? trailing {
                VStack(spacing: 3) {
                    Image(systemName: symbol).font(.subheadline.weight(.semibold))
                    Text(label).font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(width: reveal, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: 12))
            }
            ArtSheet(radius: 12) {
                HStack(spacing: 10) {
                    Circle().fill(color.ink).frame(width: 8, height: 8)
                    Text(title).font(.subheadline).foregroundStyle(Paper.ink).lineLimit(1)
                    Spacer(minLength: 0)
                }
                // 왼쪽으로 밀린 줄은 글머리가 화면 밖으로 나가므로 그만큼 안으로 — 글은 읽혀야 한다.
                .padding(.leading, leading != nil ? 12 : reveal + 18)
                .padding(.trailing, 12)
                .frame(height: 44)
            }
            .offset(x: leading != nil ? reveal + 6 : -(reveal + 6))
        }
        .clipped()
    }
}

// MARK: - 4. 달력

private struct CalendarArt: View {
    private static let weekdays = DateWords.weekdayLetters()
    /// 두 주 — 오늘은 21, 고른 날은 23.
    private static let weeks: [[Int]] = [[14, 15, 16, 17, 18, 19, 20], [21, 22, 23, 24, 25, 26, 27]]
    private static let today = 21
    private static let picked = 23
    private static let marks: [Int: [MemoColor]] = [15: [.yellow, .blue], 17: [.green], 23: [.blue, .green, .yellow], 24: [.pink]]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(index == 0 ? Theme.sundayInk : index == 6 ? Theme.saturdayInk : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(Self.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in cell(day) }
                }
            }
            ArtSheet(radius: 12) {
                HStack(spacing: 10) {
                    Text(verbatim: "15:00").font(.caption.monospacedDigit()).foregroundStyle(Theme.highlightInk)
                    Circle().fill(MemoColor.blue.ink).frame(width: 8, height: 8)
                    Text("치과 예약 — 강남역 3번 출구").font(.subheadline).foregroundStyle(Paper.ink).lineLimit(1)
                    Spacer(minLength: 0)
                    Label("이 날에 적기", systemImage: "pencil").font(.caption).foregroundStyle(Theme.accentInk).lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
            }
            .padding(.top, 4)
        }
    }

    private func cell(_ day: Int) -> some View {
        let isToday = day == Self.today
        let isPicked = day == Self.picked
        let inks = Self.marks[day] ?? []
        return ZStack {
            if isToday {
                Circle().fill(Theme.accent).frame(width: 30, height: 30)
            } else if isPicked {
                Circle().fill(Theme.accentInk.opacity(0.16)).frame(width: 30, height: 30)
            }
            Text(String(day))
                .font(.subheadline.monospacedDigit().weight(isToday || isPicked ? .semibold : .regular))
                .foregroundStyle(isToday ? Theme.onAccent : Paper.ink)
            if !inks.isEmpty {
                HStack(spacing: 2.5) {
                    ForEach(Array(inks.enumerated()), id: \.offset) { _, color in
                        Circle().fill(isToday ? Theme.onAccent : color.ink).frame(width: 4.5, height: 4.5)
                    }
                }
                .offset(y: 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
    }
}

// MARK: - 5. 앱 밖의 문

private struct DoorsArt: View {
    var body: some View {
        HStack(spacing: 10) {
            tile {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("지금").font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        Capsule().fill(MemoColor.green.ink).frame(width: 3, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("오늘 일정 · 15:00").font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.accentInk)
                            Text("치과 예약").font(.caption.weight(.semibold)).foregroundStyle(Paper.ink)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(Color.secondary, lineWidth: 1).frame(width: 11, height: 11)
                        Text("우유").font(.caption2).foregroundStyle(Paper.ink)
                    }
                    Spacer(minLength: 0)
                    Text("위젯").font(.caption2).foregroundStyle(.secondary)
                }
            }
            tile {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Theme.accentInk)
                    Text("lazymemo 에 적기").font(.caption2.weight(.medium)).foregroundStyle(Paper.ink).multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                    Text("공유 시트").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            tile {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "waveform")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Theme.accentInk)
                    Text("“lazymemo 에 적기”").font(.caption2.weight(.medium)).foregroundStyle(Paper.ink).multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                    Text("Siri · 액션 버튼").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 124)
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ArtSheet(radius: 14) {
            content()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
