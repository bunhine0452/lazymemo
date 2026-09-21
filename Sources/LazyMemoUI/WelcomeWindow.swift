import AppKit
import LazyMemoCore
import SwiftUI

/// 첫 실행과 메뉴의 사용 안내가 같은 화면을 공유한다.
@MainActor
final class WelcomeWindow {
    private var window: NSWindow?

    func show(shortcuts: WelcomeShortcuts, onCapture: @escaping () -> Void,
              onCalendar: @escaping () -> Void, onDrawer: @escaping () -> Void) {
        if let window, window.isVisible { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = L("lazymemo 시작하기")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView(
            shortcuts: shortcuts,
            onCapture: { [weak window] in window?.close(); onCapture() },
            onCalendar: { [weak window] in window?.close(); onCalendar() },
            onDrawer: { [weak window] in window?.close(); onDrawer() }
        ))
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

/// 지금 설정된 단축키 — 안내는 기본값이 아니라 **이 컴퓨터의 조합**을 말한다.
struct WelcomeShortcuts {
    var capture = "⌥⌘N"
    var paste = "⌥⌘V"
    var peek = "⌥⌘P"
    var here = "⌥⌘L"
}

/// 「lazymemo 시작하기」 — 다섯 단계, 읽는 안내가 아니라 **만져 보는 안내**.
///
/// 01·02 는 진짜 파서를 두드리는 연습이고, 03·04 는 종이·서랍·달력이 무엇을 하는지를 작은 그림으로,
/// 05 는 이 컴퓨터의 단축키와 메뉴바 두 번 클릭, 로그인 시작 스위치다. 적는 말은 앱이 실제로 하는
/// 일만이다 (README 「쓰는 법」과 같은 말 — 2026-09-21 에 0.9.x 에 맞춰 다시 씀).
struct WelcomeView: View {
    var shortcuts = WelcomeShortcuts()
    var onCapture: () -> Void = {}
    var onCalendar: () -> Void = {}
    var onDrawer: () -> Void = {}
    @Environment(\.rendersStatically) private var rendersStatically
    @State private var step = 0
    @State private var draft = ""
    @State private var saved = false
    @State private var scheduled = L("내일 오후 3시 치과 @강남역")
    @State private var tucked = false
    /// 「로그인할 때 시작」 — 화면은 실제 상태를 말한다 (`LoginItem`). 켜는 것은 사람이다.
    @State private var startsAtLogin = LoginItem.isEnabled

    static let stepCount = 5

    init(shortcuts: WelcomeShortcuts = WelcomeShortcuts(), onCapture: @escaping () -> Void = {},
         onCalendar: @escaping () -> Void = {}, onDrawer: @escaping () -> Void = {},
         initialStep: Int = 0) {
        self.shortcuts = shortcuts
        self.onCapture = onCapture
        self.onCalendar = onCalendar
        self.onDrawer = onDrawer
        _step = State(initialValue: min(max(initialStep, 0), Self.stepCount - 1))
    }

    private var last: Bool { step == Self.stepCount - 1 }

    private let labels = [L("01 · 바로 적기"), L("02 · 날짜에 맡기기"), L("03 · 종이와 서랍"), L("04 · 달력과 다시 보기"), L("05 · 준비 완료")]
    private let titles = [
        L("떠오른 생각, 한 줄이면 돼요."),
        L("날짜도 자리도 말하듯 적어 보세요."),
        L("종이는 바탕화면에 눕고, 치우면 서랍에 있어요."),
        L("날짜가 붙으면 달력이 맡아요."),
        L("이제, 가볍게 시작하세요."),
    ]
    private let details = [
        L("어느 앱에서든 단축키 한 번으로 빠른 입력이 뜹니다. 치면 기존 메모가 걸러지고, ⌘↵ 로 남깁니다."),
        L("「내일 오후 3시 치과 @강남역」— 날짜·시각·자리를 앱이 읽어 달력에 놓습니다. 형식을 배울 일이 없어요."),
        L("종이는 다른 앱 창 뒤에 눕는 것이 이 앱의 뜻이에요. × 는 삭제가 아니라 서랍이고, 끝난 것은 스스로 물러납니다."),
        L("메모와 일정을 따로 만들지 않아요. 날짜가 붙은 메모가 곧 일정이고, 다시 볼 시각은 따로 정합니다."),
        L("메뉴바의 작은 아이콘이 언제나 메모로 돌아오는 길이에요. 메모는 내 Mac 과 iCloud Drive 의 파일입니다."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                MemoBrandMark()
                Text("lazymemo").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(L("처음 만나는 lazymemo")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(0..<Self.stepCount, id: \.self) { index in
                    Capsule().fill(index <= step ? Theme.accentInk : Theme.softAccent).frame(height: 3)
                }
            }.padding(.top, 25).accessibilityLabel(L("튜토리얼 \(step + 1) / \(Self.stepCount) 단계"))
            Text(labels[step])
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accentInk).padding(.top, 24)
            Text(titles[step]).font(.system(size: 26, weight: .semibold)).tracking(-0.8).padding(.top, 10)
            Text(details[step]).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(3).padding(.top, 8)
            practice.padding(.top, 22)
            Spacer(minLength: 16)
            HStack {
                if step > 0 { Button(L("이전")) { step -= 1 }.buttonStyle(.plain).padding(.trailing, 16) }
                Button(last ? L("달력 열기") : L("건너뛰고 메모 적기"), action: last ? onCalendar : onCapture)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(action: { if last { onCapture() } else { step += 1 } }) {
                    HStack(spacing: 14) {
                        Text(last ? L("첫 메모 적기") : L("다음"))
                        Image(systemName: "arrow.right")
                    }.font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20).frame(height: 42)
                        .foregroundStyle(Theme.onAccent)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }.font(.system(size: 12))
            Text(L("다시 보려면 메뉴바 아이콘 오른쪽 클릭 → 시작하기 및 사용 안내"))
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 20)
        }
        .padding(36).padding(.top, 18)
        .frame(width: 660, height: 640)
        .background(Theme.paper(MemoColor.gray.ink, radius: 0, dotted: false))
    }

    private func practiceField(_ placeholder: String, text: Binding<String>) -> some View {
        Group {
            if rendersStatically {
                Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
                    .foregroundStyle(text.wrappedValue.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(placeholder, text: text).textFieldStyle(.plain)
                    .accessibilityLabel(placeholder)
            }
        }
        .font(.system(size: 17)).padding(14)
        .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var practice: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case 0: capturePractice
            case 1: datePractice
            case 2: paperAndDrawer
            case 3: calendarAndRecall
            default: ready
            }
            if step < 2 {
                Text(L("연습 공간 · 여기에 적은 내용은 저장되지 않아요"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Theme.paper(MemoColor.yellow.ink))
        .overlay(Theme.edge())
    }

    // MARK: 01 · 바로 적기

    @ViewBuilder private var capturePractice: some View {
        HStack {
            Label(L("빠른 입력 연습"), systemImage: "square.and.pencil")
            Spacer()
            Text(shortcuts.capture).monospaced().foregroundStyle(Theme.accentInk)
        }
        practiceField(L("지금 떠오르는 생각을 적어 보세요"), text: $draft)
            .onChange(of: draft) { saved = false }
        HStack {
            Text(saved ? L("잘했어요! 실제 입력창에서는 메모 한 장이 생겨요.") : L("빠른 입력은 ⌘↵ 또는 「메모 남기기」로 확정해요."))
            Spacer()
            Button(saved ? L("연습 완료 ✓") : L("남기기")) { saved = true }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
        }
        Text(L("같은 상자에 치면 기존 메모를 찾아요 — 「ㅈㅂㄱ」처럼 첫소리만 쳐도 「장보기」가 나옵니다. 바탕화면의 종이를 고칠 때는 자동으로 저장돼요."))
            .foregroundStyle(.secondary).lineSpacing(4)
    }

    // MARK: 02 · 날짜에 맡기기

    @ViewBuilder private var datePractice: some View {
        Label(L("날짜 인식 연습"), systemImage: "calendar")
        practiceField(L("예: 내일 오후 3시 치과 @강남역"), text: $scheduled)
        if let result = NaturalDateParser.parse(scheduled) {
            Label(L("인식한 표현: \(result.phrases.joined(separator: " · "))"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accentInk)
        } else {
            Text(L("날짜가 없는 글은 일반 메모로 남아요.")).foregroundStyle(.secondary)
        }
        Text(L("문장을 바꿔 보세요. 「@강남역」은 자리가 되고, 「매주 화요일」처럼 되풀이 낱말을 적으면 회차가 지날 때 다음으로 옮겨 둡니다. 날짜가 붙은 메모는 달력에서 만나요."))
            .foregroundStyle(.secondary).lineSpacing(4)
    }

    // MARK: 03 · 종이와 서랍

    @ViewBuilder private var paperAndDrawer: some View {
        HStack(alignment: .top, spacing: 16) {
            // 종이 한 장 — × 와 색띠, 그리고 서랍 탭.
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("언젠가 가 보고 싶은 곳")).font(.system(size: 13, weight: .semibold))
                        Text(L("교토 · 가을에")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(12).padding(.top, 4)
                    .frame(width: 200, height: 96, alignment: .topLeading)
                    .background(Theme.paper(MemoColor.green.ink, radius: 10))
                    .overlay(Theme.edge(radius: 10))
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 18, height: 18).background(Theme.softAccent, in: Circle())
                        .padding(6)
                }
                .opacity(tucked ? 0.35 : 1)
                HStack(spacing: 6) {
                    Image(systemName: "tray.full").font(.system(size: 11))
                    Text(tucked ? L("서랍 1") : L("서랍 0")).font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10).frame(height: 26)
                .background(Theme.paper(MemoColor.gray.ink, radius: 8, dotted: false))
                .overlay(Theme.edge(radius: 8))
            }
            VStack(alignment: .leading, spacing: 10) {
                Button(tucked ? L("다시 꺼내기") : L("서랍에 넣어 보기")) { tucked.toggle() }
                Text(L("실제 종이의 × 나 esc 가 하는 일이 이것이에요 — 삭제가 아니라 바탕화면 왼쪽 아래 「서랍」 탭으로 들어가고, 탭이나 메뉴바 「서랍」에서 줄을 누르면 돌아옵니다."))
                    .foregroundStyle(.secondary).lineSpacing(4)
                Label(L("\(shortcuts.peek) — 브라우저 뒤에 누운 종이를 전부 잠깐 앞에 세워요. 몇 초 뒤 스스로 눕고, 그 사이 누른 종이만 남습니다."), systemImage: "rectangle.stack")
                    .lineSpacing(4)
                Text(L("다 체크한 목록은 사흘 뒤, 지난 일정은 다음 날 스스로 물러나요. 파일에는 그대로 있고 메뉴가 「치워 둔 N장」이라고 적어 둡니다."))
                    .foregroundStyle(.secondary).lineSpacing(4)
            }
        }
    }

    // MARK: 04 · 달력과 다시 보기

    @ViewBuilder private var calendarAndRecall: some View {
        HStack(alignment: .top, spacing: 16) {
            // 달력 한 조각 — 오늘의 동그라미, 일정이 있는 칸의 잉크.
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(Array(DateWords.weekdayLetters().enumerated()), id: \.offset) { _, name in
                        Text(name).font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                ForEach([[14, 15, 16, 17, 18, 19, 20], [21, 22, 23, 24, 25, 26, 27]], id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            ZStack {
                                if day == 21 { Circle().strokeBorder(Theme.accentInk, lineWidth: 1.4).frame(width: 22, height: 22) }
                                if [15, 23, 24].contains(day) {
                                    RoundedRectangle(cornerRadius: 4).fill(Theme.highlightInk.opacity(day == 23 ? 0.3 : 0.16)).frame(width: 24, height: 24)
                                }
                                Text(String(day)).font(.system(size: 11, weight: day == 21 ? .semibold : .regular).monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, minHeight: 28)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text(verbatim: "15:00").font(.system(size: 10).monospacedDigit()).foregroundStyle(Theme.highlightInk)
                    Circle().fill(MemoColor.blue.ink).frame(width: 6, height: 6)
                    Text(L("치과")).font(.system(size: 11))
                    Spacer(minLength: 0)
                    Text(L("미루기 · 종이로")).font(.system(size: 10)).foregroundStyle(Theme.accentInk)
                }
                .padding(.horizontal, 8).frame(height: 24)
                .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 6))
                .padding(.top, 4)
            }
            .frame(width: 210)
            VStack(alignment: .leading, spacing: 10) {
                Label(L("종이 위 달력 아이콘 → 「달력에 놓기」— 칸을 하나 누르면 그 날로. 날짜가 붙으면 종이는 물러나고 달력이 맡아요."), systemImage: "calendar")
                    .lineSpacing(4)
                Label(L("칸을 누르면 그 날이 아래에 서고, 일정 줄의 「미루기」는 하루, 다른 칸으로 끌면 그 날로. 「종이로」는 날짜를 떼어 바탕화면으로 돌려보내요."), systemImage: "hand.point.up.left")
                    .lineSpacing(4)
                Label(L("종이 우클릭 「다시 보기…」— 「한 시간 뒤」「내일 아침 9시」를 누르면 그때 종이가 앞으로 나와요. 일정은 그대로. 알림은 설정에서 「이 기기에서 알림 받기」를 켤 때만."), systemImage: "bell")
                    .lineSpacing(4)
            }
        }
    }

    // MARK: 05 · 준비 완료

    @ViewBuilder private var ready: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
            GridRow {
                Text(shortcuts.capture).monospaced().foregroundStyle(Theme.accentInk)
                Text(L("빠른 입력 — 어디서든 한 줄 적기, 치면 찾기"))
            }
            GridRow {
                Text(shortcuts.paste).monospaced().foregroundStyle(Theme.accentInk)
                Text(L("클립보드 즉시 메모 — 복사한 글·사진이 창 없이 종이가 돼요"))
            }
            GridRow {
                Text(shortcuts.peek).monospaced().foregroundStyle(Theme.accentInk)
                Text(L("종이 보기 — 다른 창 뒤의 종이를 전부 잠깐 앞에"))
            }
            GridRow {
                Text(shortcuts.here).monospaced().foregroundStyle(Theme.accentInk)
                Text(L("지금 여기 — 이 자리를 한 번 재어 메모에 붙여요 (누를 때만 위치를 묻습니다)"))
            }
        }
        Divider()
        Label(L("메뉴바 아이콘 클릭 → 빠른 입력 · 오른쪽 클릭 → 달력 · 서랍 · 종이 보기 · 설정"), systemImage: "menubar.arrow.up.rectangle")
        Divider()
        // 이 앱은 켜져 있지 않으면 아무것도 아니다 — 그 스위치를 설정 메뉴 아홉째 줄에만 두면
        // 게으른 사람은 영영 못 만난다. 첫 실행이 한 번 내민다 (2026-09-17 편의성 감사 §2.3).
        // HIG Menu bar extras: "To ensure discoverability… consider giving people the option… during setup."
        // 권한을 묻지 않는 스위치(`SMAppService`)라 「첫 실행에 아무것도 묻지 않는다」와 부딪히지 않는다.
        if LoginItem.isAvailable {
            Toggle(isOn: $startsAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("로그인할 때 시작"))
                    Text(L("껐다 켜도 종이가 그대로 떠 있어요. 언제든 설정에서 바꿀 수 있어요."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .onChange(of: startsAtLogin) { _, on in
                // 실패하면 체크가 도로 풀린다 — 화면이 실제 상태를 말한다.
                if !LoginItem.set(on) { startsAtLogin = LoginItem.isEnabled }
            }
            .accessibilityIdentifier("welcome-login-item")
        }
        Text(L("메모는 마크다운 파일이에요 — 가입 없이 바로 시작하세요. 아이폰과 같이 보려면 설정 → 「iCloud 로 동기화…」, 단축키도 거기서 바꿔요."))
            .foregroundStyle(.secondary).lineSpacing(4)
    }
}
