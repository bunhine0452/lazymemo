import SwiftUI

/// 첫 실행의 안내 — 다섯 장, 한 장에 한 손짓.
///
/// 설정 화면이 없는 앱이라 사용법을 둘 곳이 이것뿐이다. 첫 실행에 한 번 뜨고,
/// 그 뒤로는 More 메뉴의 「사용법」으로만 돌아온다. 안내가 떠 있는 동안은 펜이
/// 키보드를 올리지 않는다 (`PenModel.holdsLaunchFocus`) — 시트 위로 키보드가
/// 오르면 안내를 읽을 수 없다. 닫히면 그때 펜이 올라온다.
///
/// 장마다 **그림이 먼저다** — 앱의 진짜 부품을 작게 그린 것(`TutorialArt`)이라 안내를 닫았을 때
/// 눈이 이미 아는 것을 만난다. 글은 읽는 사람이 손을 움직일 수 있게 「밀기·길게 누르기·
/// 흔들기」처럼 **손짓의 이름**으로 적는다. 기능 목록이 아니다. 적는 말은 앱이 실제로 하는
/// 일만이다 — 여기 적힌 손짓은 전부 본 화면에 그대로 있다 (2026-09-21 에 0.9.x 에 맞춰 다시 씀).
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private static let pages: [Page] = [
        Page(
            art: .pen,
            title: String(localized: "아래 펜에 한 줄, 그걸로 끝"),
            lines: [
                String(localized: "한 줄을 적고 **남기기**. 저장 단추도 제목도 없어요 — 적던 글은 앱을 닫아도 남습니다."),
                String(localized: "「내일 3시 치과 @강남역」이라고 적으면 날짜·시각·장소가 **칩**으로 먼저 보이고, 단추는 「달력에 남기기」가 됩니다. 칩을 누르면 그 해석만 끕니다."),
                String(localized: "같은 칸에 치면 **찾습니다** — 「ㅊㄱ」처럼 첫소리만 쳐도 「치과」가 나와요. 「치과 언제였지?」처럼 물으면 메모가 답합니다 — 모델을 한 번 받으면, 전부 이 폰 안에서."),
            ]
        ),
        Page(
            art: .now,
            title: String(localized: "「지금」이 오늘을 챙겨요"),
            lines: [
                String(localized: "목록 위 「**지금**」에 오늘 다시 볼 것·오늘 일정·고정한 메모가 세 장까지 서요 — 다가오는 시각부터. 본 카드는 「봤어요」로 내려놓습니다."),
                String(localized: "편집 화면의 **종 단추**로 「한 시간 뒤」「내일 아침 9시」를 정하면 그때 다시 오릅니다. 일정은 그대로예요."),
                String(localized: "알림은 **더 보기 → 알림**에서 켤 때만, 이 기기에서만 울립니다. 켜지 않아도 「지금」이 알려 줘요."),
            ]
        ),
        Page(
            art: .gestures,
            title: String(localized: "밀고, 길게 누르고, 흔들기"),
            lines: [
                String(localized: "줄을 **오른쪽**으로 밀면 고정 — 일정이 있는 줄은 **하루 미루기**가 먼저예요. **왼쪽**으로 끝까지 밀면 지우기."),
                String(localized: "길게 누르면 폴더에 넣기·달력에 놓기. 지운 것은 **휴지통**에 30일 남고, 폰을 흔들면 방금 한 일을 되돌립니다."),
            ]
        ),
        Page(
            art: .calendar,
            title: String(localized: "달력은 만지는 물건"),
            lines: [
                String(localized: "날을 누르면 그 날의 메모가 아래에 서고, 「**이 날에 적기**」로 그 날짜가 물린 메모를 시작해요. 좌우로 쓸면 달이 넘어갑니다."),
                String(localized: "칸 밑의 점은 그 날의 메모 — **색이 곧 메모의 색**이에요. 줄을 오른쪽으로 밀면 하루 미루기, 길게 눌러 끌어 다른 칸에 놓으면 그 날로 옮깁니다."),
                String(localized: "「매주 화요일 분리수거」처럼 되풀이 낱말을 적으면 회차가 지날 때 다음 회차로 옮겨 둡니다."),
            ]
        ),
        Page(
            art: .doors,
            title: String(localized: "앱을 열지 않아도"),
            lines: [
                String(localized: "홈 화면 위젯 넷 — **지금·다음 약속·달력·적기**. 「봤어요」와 체크상자는 위젯에서 바로 눌러요."),
                String(localized: "다른 앱에서 **공유 → 「lazymemo 에 적기」**. Siri 에게 「**lazymemo 에 적기**」라고 말하면 앱을 열지 않고 메모가 됩니다."),
                String(localized: "메모는 iCloud Drive 의 「LazyMemo」 폴더에 마크다운 파일로 남아요 — 맥의 lazymemo 와 같은 폴더, 계정도 서버도 없습니다. 종이 여덟 벌은 **더 보기 → 테마**."),
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
            VStack(alignment: .leading, spacing: 18) {
                TutorialArtView(art: item.art)
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Paper.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(item.lines.enumerated()), id: \.offset) { _, line in
                        Text(.init(line))
                            .font(.body)
                            .foregroundStyle(Paper.ink)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
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
        let art: TutorialArt
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
