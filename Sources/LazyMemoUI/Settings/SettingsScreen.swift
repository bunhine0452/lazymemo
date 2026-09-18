import LazyMemoCore
import Observation
import SwiftUI

/// 설정 창이 그리는 **한 장의 사진** — 메뉴바 컨트롤러가 찍어 준다 (`MenuBarController.settingsSnapshot`).
///
/// 값의 주인은 제각각이다 — 설정 파일·로그인 항목·Spotlight·위치 감시·업데이트. 창이 그것들을
/// 하나씩 관찰하게 두면 주인이 바뀔 때마다 창도 고쳐야 한다. 그래서 창은 사진 한 장을 보고,
/// 손을 댄 뒤에는 새로 찍는다 (`SettingsScreenModel.reload`).
struct SettingsState: Equatable {
    struct Shortcut: Equatable {
        var name: String
        /// 다른 앱이 쓰고 있어 걸리지 않았다.
        var taken: Bool
    }
    struct Cloud: Equatable {
        /// 이미 iCloud 폴더를 보고 있다 — 누를 것이 없다.
        var syncing: Bool
    }
    struct Claude: Equatable {
        var usesClaude: Bool
        var morningBrief: Bool
    }
    struct Updates: Equatable {
        var checks: Bool
        /// 「0.8.3 — 최신입니다」처럼 지금 판의 한 줄.
        var line: String
        /// 새 판이 있으면 그 단추의 이름 (「0.8.4 로 바꾸기」·「brew 명령 복사」).
        var action: String?
    }

    var capture: Shortcut
    var paste: Shortcut
    var loginEnabled: Bool
    var loginAvailable: Bool

    var opacity: Double
    var embedsLinks: Bool

    var vaultPath: String
    var cloud: Cloud

    var watchesPlaces: Bool
    var placesNote: String
    /// 「지금 여기」의 권한 상태. `nil` 이면 할 말이 없다.
    var hereNote: String?
    var asksRoutes: Bool

    var showsSystemEvents: Bool
    /// 캘린더 권한이 막혔을 때의 말. `nil` 이면 잘 되고 있다.
    var eventsNote: String?
    var spotlight: Bool
    var spotlightTrouble: String?

    var remindersOn: Bool

    /// 없으면 그 절이 통째로 없다 — App Store 판, `claude` 없는 맥.
    var claude: Claude?
    /// 없으면 그 절이 통째로 없다 — App Store 판, 개발 빌드.
    var updates: Updates?
}

/// 창이 누르는 단추들. 하는 일은 전부 메뉴바 컨트롤러의 것이다 — 창은 이름만 안다.
struct SettingsActions {
    var changeCaptureShortcut: () -> Void = {}
    var changePasteShortcut: () -> Void = {}
    var setLogin: (Bool) -> Void = { _ in }
    var setOpacity: (Double) -> Void = { _ in }
    var setEmbedsLinks: (Bool) -> Void = { _ in }
    var moveVault: () -> Void = {}
    var openVault: () -> Void = {}
    var syncToCloud: () -> Void = {}
    var setWatchesPlaces: (Bool) -> Void = { _ in }
    var setAsksRoutes: (Bool) -> Void = { _ in }
    var setShowsSystemEvents: (Bool) -> Void = { _ in }
    var setSpotlight: (Bool) -> Void = { _ in }
    var showReminders: () -> Void = {}
    var setUsesClaude: (Bool) -> Void = { _ in }
    var setMorningBrief: (Bool) -> Void = { _ in }
    var setChecksUpdates: (Bool) -> Void = { _ in }
    var checkUpdates: () -> Void = {}
    /// 새 판을 받거나(독립 판) brew 명령을 복사한다(brew 판).
    var takeUpdate: () -> Void = {}
}

/// 설정 창의 모델. 사진을 들고 있다가, 손을 댄 뒤 다시 찍는다.
@MainActor
@Observable
final class SettingsScreenModel {
    private(set) var state: SettingsState
    let actions: SettingsActions
    private let snapshot: () -> SettingsState

    init(snapshot: @escaping () -> SettingsState, actions: SettingsActions) {
        self.snapshot = snapshot
        self.actions = actions
        self.state = snapshot()
    }

    /// 다시 찍는다. 권한 창에서 돌아왔을 때, 단추를 누른 뒤에.
    func reload() {
        let next = snapshot()
        if next != state { state = next }
    }

    /// 누른 뒤 새로 찍는다. 시스템에 묻는 것(위치·로그인 항목)은 답이 늦게 오므로 한 번 더.
    func perform(_ action: () -> Void) {
        action()
        reload()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.reload()
        }
    }
}

/// 「lazymemo 설정」 — 한 판, 여섯 묶음.
///
/// 앞선 판은 메뉴바 메뉴의 하위 메뉴였다. 항목이 열넷에 설명이 두 줄씩 붙으니 메뉴가 화면
/// 반을 차지했고, 켜고 끄는 것과 여는 것과 상태만 적은 것이 한 줄 모양으로 섞여 있었다.
/// HIG Settings(macOS): "When people choose the Settings item … your custom settings window
/// opens" · "If your settings window doesn't have multiple panes, use the title App Name
/// Settings" · Best practices: "Minimize the number of settings you offer … making it hard to
/// find a particular setting". 묶음은 **무엇을 건드리는가**로 — 입력 · 종이 · 메모가 있는 곳 ·
/// 자리 · 함께 보기 · 알림, 그리고 판에 따라 Claude · 업데이트. 설명은 각 묶음의 바닥 글로
/// 내려가 (HIG Forms: 「footer」) 줄 모양이 «이름 — 스위치» 하나로 통일된다.
struct SettingsView: View {
    @Bindable var model: SettingsScreenModel
    /// 창이 화면에서 넘겨받은 키의 상한 (`SettingsWindow`).
    var maxHeight: CGFloat = 880

    private var state: SettingsState { model.state }
    private var act: SettingsActions { model.actions }

    var body: some View {
        Form {
            input
            paper
            vault
            places
            together
            reminders
            if state.claude != nil { claude }
            if state.updates != nil { updates }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        // 판 하나가 통째로 보이는 키까지 — 그보다 길면 판이 스크롤한다 (시스템 설정과 같다).
        .frame(minHeight: 420, maxHeight: maxHeight)
        .onAppear { model.reload() }
        // 시스템 권한 창이나 Finder 에 다녀오면 값이 바뀌어 있다.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.reload()
        }
    }

    // MARK: 입력

    private var input: some View {
        Section {
            shortcutRow(L("빠른 입력"), state.capture, action: act.changeCaptureShortcut)
            shortcutRow(L("클립보드 즉시 메모"), state.paste, action: act.changePasteShortcut)
            Toggle(L("로그인할 때 시작"), isOn: binding(state.loginEnabled, act.setLogin))
                .disabled(!state.loginAvailable)
        } header: {
            Text(L("입력"))
        } footer: {
            Text(state.loginAvailable
                 ? L("단축키는 어느 앱에서나 듣습니다. 로그인할 때 시작을 켜 두면 껐다 켜도 메모가 그대로 떠 있습니다")
                 : L("앱 번들로 실행할 때만 로그인 항목을 켤 수 있습니다"))
        }
    }

    private func shortcutRow(_ name: String, _ shortcut: SettingsState.Shortcut, action: @escaping () -> Void) -> some View {
        LabeledContent(name) {
            HStack(spacing: 10) {
                if shortcut.taken {
                    Label(L("다른 앱이 쓰고 있습니다"), systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.orange)
                }
                Text(shortcut.name)
                    .font(.system(.body, design: .rounded).weight(.medium)).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Button(L("바꾸기…")) { model.perform(action) }
            }
        }
    }

    // MARK: 종이

    private var paper: some View {
        Section {
            Picker(L("투명도"), selection: binding(state.opacity, act.setOpacity)) {
                ForEach(PaperAppearance.steps, id: \.opacity) { step in
                    Text(step.label).tag(step.opacity)
                }
            }
            .pickerStyle(.segmented)
            Toggle(L("링크를 카드로 펼치기"), isOn: binding(state.embedsLinks, act.setEmbedsLinks))
        } header: {
            Text(L("종이"))
        } footer: {
            Text(L("비치게 해 둔 종이도 포인터를 올리면 원래대로 진해집니다. 링크 카드는 제목과 그림을 가져오려고 그 주소에 접속합니다"))
        }
    }

    // MARK: 메모가 있는 곳

    private var vault: some View {
        Section {
            LabeledContent(L("폴더")) {
                HStack(spacing: 10) {
                    Text(state.vaultPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: 230, alignment: .trailing)
                        .help(state.vaultPath)
                    Button(L("열기")) { act.openVault() }
                    Button(L("옮기기…")) { model.perform(act.moveVault) }
                        .help(L("고른 폴더에 이미 메모가 있으면 옮기지 않고 그것을 씁니다"))
                }
            }
            LabeledContent(L("iCloud")) {
                if state.cloud.syncing {
                    Label(L("동기화 중"), systemImage: "checkmark.icloud")
                        .foregroundStyle(.secondary)
                } else {
                    Button(L("iCloud 로 동기화…")) { model.perform(act.syncToCloud) }
                }
            }
        } header: {
            Text(L("메모가 있는 곳"))
        } footer: {
            Text(state.cloud.syncing
                 ? L("아이폰의 lazymemo 와 같은 폴더를 봅니다 — 어느 쪽에서 적어도 양쪽에 있습니다")
                 : L("iCloud Drive 의 LazyMemo 폴더로 옮기면 아이폰과 같은 자리를 봅니다. 이미 거기 메모가 있으면 합칩니다"))
        }
    }

    // MARK: 자리

    private var places: some View {
        Section {
            Toggle(L("적어 둔 자리에 가면 그 종이 꺼내기"), isOn: binding(state.watchesPlaces, act.setWatchesPlaces))
            if let note = state.hereNote {
                LabeledContent(L("지금 여기 (⌥⌘L)")) {
                    Text(note).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
            }
            Toggle(L("약속을 적으면 가는 길 묻기"), isOn: binding(state.asksRoutes, act.setAsksRoutes))
        } header: {
            Text(L("자리"))
        } footer: {
            Text(state.placesNote + "\n" + L("가는 길은 「어디서 출발하시나요?」에 답할 때만 지도와 길찾기에 접속합니다"))
        }
    }

    // MARK: 함께 보기

    private var together: some View {
        Section {
            Toggle(L("달력에 시스템 일정 함께 보기"), isOn: binding(state.showsSystemEvents, act.setShowsSystemEvents))
            Toggle(L("Spotlight 에서 찾기"), isOn: binding(state.spotlight, act.setSpotlight))
        } header: {
            Text(L("함께 보기"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.eventsNote ?? L("일정은 읽기만 합니다 — 달력을 처음 열 때 한 번 묻습니다"))
                Text(state.spotlightTrouble ?? L("메모 제목과 글이 이 맥의 검색에 보입니다. 기기 밖으로 나가지 않습니다"))
            }
        }
    }

    // MARK: 알림

    private var reminders: some View {
        Section {
            LabeledContent(L("이 기기에서 알림")) {
                HStack(spacing: 10) {
                    Text(state.remindersOn ? L("켜짐") : L("꺼짐")).foregroundStyle(.secondary)
                    Button(L("설정…")) { act.showReminders() }
                }
            }
        } header: {
            Text(L("알림"))
        } footer: {
            Text(L("일정 시각과 다시 볼 시각에 이 기기가 알립니다"))
        }
    }

    // MARK: Claude — GitHub 판에서 `claude` 가 있을 때만

    private var claude: some View {
        Section {
            Toggle(L("종이에서 Claude 부르기"), isOn: binding(state.claude?.usesClaude ?? false, act.setUsesClaude))
            Toggle(L("아침 여덟 시에 브리핑 놓기"), isOn: binding(state.claude?.morningBrief ?? false, act.setMorningBrief))
        } header: {
            Text("Claude")
        } footer: {
            Text(L("종이의 ✧ 를 누를 때만 그 종이가 나갑니다 · 8초 안에 되돌릴 수 있습니다. 아침 브리핑은 매일 메모를 Claude 에게 보냅니다 — 구독 사용량이 듭니다"))
        }
    }

    // MARK: 업데이트 — App Store 밖의 판만

    private var updates: some View {
        Section {
            Toggle(L("새 판이 나오면 알기"), isOn: binding(state.updates?.checks ?? false, act.setChecksUpdates))
            LabeledContent(L("지금 판")) {
                HStack(spacing: 10) {
                    Text(state.updates?.line ?? "").foregroundStyle(.secondary)
                    if let action = state.updates?.action {
                        Button(action) { model.perform(act.takeUpdate) }
                    } else {
                        Button(L("확인")) { model.perform(act.checkUpdates) }
                    }
                }
            }
        } header: {
            Text(L("업데이트"))
        } footer: {
            Text(L("GitHub 에 판 번호만 물어봅니다 — 메모는 나가지 않습니다"))
        }
    }

    // MARK: 값 ↔ 단추

    /// 사진의 값을 보이고, 바꾸면 주인에게 넘긴 뒤 다시 찍는다.
    private func binding<T>(_ value: T, _ set: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: { value }, set: { next in model.perform { set(next) } })
    }
}
