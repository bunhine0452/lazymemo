import SwiftUI

/// 첫 실행의 안내 — 네 장, 한 장에 한 손짓.
///
/// 설정 화면이 없는 앱이라 사용법을 둘 곳이 이것뿐이다. 첫 실행에 한 번 뜨고,
/// 그 뒤로는 More 메뉴의 「사용법」으로만 돌아온다. 안내가 떠 있는 동안은 펜이
/// 키보드를 올리지 않는다 (`PenModel.holdsLaunchFocus`) — 시트 위로 키보드가
/// 오르면 안내를 읽을 수 없다. 닫히면 그때 펜이 올라온다.
///
/// 읽는 사람이 손을 움직일 수 있게 「밀기·길게 누르기·흔들기」처럼 **손짓의
/// 이름**으로 적는다. 기능 목록이 아니다.
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private static let pages: [Page] = [
        Page(
            symbol: "pencil.line",
            title: String(localized: "아래 펜에 적고, 남기기"),
            lines: [
                String(localized: "한 줄이면 메모가 됩니다. 적던 글은 앱을 닫아도 남아 있어요."),
                String(localized: "같은 칸에 치면 메모를 **찾습니다** — 「ㅊㄱ」처럼 첫소리만 쳐도 「치과」가 나와요."),
                String(localized: "「치과 언제였지?」처럼 **물으면** 메모가 답하고, 「금요일에 다시 알려줘」처럼 **시키면** 합니다 — 전부 이 폰 안에서요."),
            ]
        ),
        Page(
            symbol: "calendar.badge.clock",
            title: String(localized: "날짜와 장소는 앱이 읽어요"),
            lines: [
                String(localized: "「내일 3시 치과 @강남역」이라고 적으면 날짜·시각·장소가 **칩**으로 먼저 보여요. 단추는 「달력에 남기기」가 됩니다."),
                String(localized: "칩을 누르면 그 해석만 끕니다. 글은 그대로예요. 왼쪽 끝 위치 단추는 「지금 여기」를 붙입니다."),
            ]
        ),
        Page(
            symbol: "hand.draw",
            title: String(localized: "밀고, 길게 누르고, 흔들기"),
            lines: [
                String(localized: "줄을 **오른쪽**으로 밀면 고정, **왼쪽**으로 밀면 지우기. 길게 누르면 폴더·달력이 나와요."),
                String(localized: "지운 것은 휴지통에 30일 남고, 흔들면 방금 한 일을 되돌립니다."),
            ]
        ),
        Page(
            symbol: "calendar",
            title: String(localized: "달력에서는 날을 고르고 적어요"),
            lines: [
                String(localized: "날을 누르면 그 날의 메모가 아래에 서고, 펜에 그 날이 미리 물립니다."),
                String(localized: "줄을 오른쪽으로 밀면 **하루 미루기**, 길게 눌러 끌면 다른 날로 옮겨요. 맥과 같은 iCloud 폴더를 봅니다."),
            ]
        ),
    ]

    private var last: Bool { page == Self.pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, item in
                        card(item).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                dots
                Button {
                    if last { dismiss() } else { withAnimation(Motion.fly(reduceMotion)) { page += 1 } }
                } label: {
                    Text(last ? String(localized: "시작하기") : String(localized: "다음"))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .accessibilityIdentifier(last ? "tutorial-done" : "tutorial-next")
            }
            .background(Paper.surface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기") { dismiss() }
                        .accessibilityIdentifier("tutorial-skip")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("tutorial")
    }

    private func card(_ item: Page) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: item.symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 104, height: 104)
                    .background(Theme.accentInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 30))
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(item.lines.enumerated()), id: \.offset) { _, line in
                        Text(.init(line))
                            .font(.body)
                            .foregroundStyle(Paper.ink)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Paper.ink.opacity(0.07), lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.accentInk : Theme.accentInk.opacity(0.25))
                    .frame(width: index == page ? 20 : 8, height: 8)
                    .animation(Motion.quick(reduceMotion), value: page)
            }
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.pages.count)장 중 \(page + 1)장")
    }

    struct Page {
        let symbol: String
        let title: String
        let lines: [String]
    }
}

/// 「봤다」는 이 기기의 일이다 — iCloud 설정에 두면 맥이 폰의 안내를 끈다.
/// 시험은 실행 인자 `-tutorialSeen YES/NO` 로 정한다 (`UserDefaults` 의 인자 도메인).
enum Tutorial {
    private static let key = "tutorialSeen"
    static var seen: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: key) }
}
