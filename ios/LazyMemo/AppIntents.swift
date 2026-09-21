import AppIntents
import Foundation
import LazyMemoCore
import LazyMemoReminders
import LazyMemoWidgetsCore

/// Siri·단축어·액션 버튼이 두드리는 문 — 적기와 오늘은 **앱을 열지 않고**, 펜만 연다.
///
/// 지금까지 폰에서 앱을 열지 않는 길은 iCloud 폴더에 `.md` 를 떨구는 단축어 우회로뿐이었다
/// (README 「아이폰에서 던지기 — 앱 없이」). 인텐트는 공유 시트와 같은 문(`InboundNote` →
/// `InboxDrop`)을 지나는 정식 길이라 「내일 3시 치과」의 날짜와 「@강남역」의 자리를 앱과 똑같이
/// 읽는다. 파일 한 장만 떨구고 나온다 — 인덱스는 앱이 다음에 앞으로 나올 때 대조하고
/// (`AppModel.foreground`), 위젯은 지금 다시 그리게 한다.
///
/// 맥 GitHub 판에는 없다 — App Intents 의 메타데이터는 Xcode 가 뽑는 것이라(편의성 감사 §3.1)
/// 이 파일은 폰 타깃에만 든다. 맥 스토어 판은 다음 판의 몫.

/// 「lazymemo 에 적기」 — 한 줄을 받아 메모로. 글이 없으면 시스템이 「무엇을 적을까요?」 하고 묻는다.
struct WriteMemoIntent: AppIntent {
    static let title: LocalizedStringResource = "lazymemo 에 적기"
    static let description = IntentDescription("한 줄을 메모로 남깁니다. 「내일 3시 치과」의 날짜와 「@강남역」의 자리는 앱이 읽습니다.")
    static let openAppWhenRun = false

    @Parameter(
        title: "글", inputOptions: String.IntentInputOptions(capitalizationType: .sentences, multiline: true),
        requestValueDialog: "무엇을 적을까요?"
    )
    var text: String

    /// 메인 액터에서 돈다 — 위젯 갱신(`WidgetRefresher`)이 그쪽 것이라. 기다리는 일은 전부 `await` 라 막지 않는다.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let inbound = InboundNote.make(text: text) else {
            throw $text.needsValueError("무엇을 적을까요?")
        }
        let paths = try await IntentVault.paths()
        let memo = try await InboxDrop.drop(inbound, into: paths)
        let group = AppPaths.sharedContainer()
        // 자리가 있는 약속이면 앱이 「어디서 출발하시나요?」를 묻게 남긴다 — 공유 시트와 같다.
        if RouteAsk.applies(memo) { await RouteAskDrop.leave(memo, group: group) }
        // 다시 보기 알림은 앱과 같은 이름으로 지금 건다 — 앱을 열기 전에 시각이 올 수 있다 (`RecallDrop`).
        let receipt = await RecallDrop.leave(memo, group: group)
        WidgetRefresher.reloadNow()
        return .result(dialog: IntentDialog("\(Self.reply(for: memo, receipt: receipt))"))
    }

    /// 「적었어요 · 9월 22일 15:00 · 달력으로 · 이 기기에 알림 예약됨 …」 — 공유 시트의 칩·영수증과 같은 말.
    /// 날짜를 읽었으면 그렇다고 하고, 알림은 **이 기기에서 확인한 사실**만 (`ReservationReceipt`).
    static func reply(for memo: Memo, receipt: ReservationReceipt? = nil) -> String {
        var parts = [String(localized: "적었어요")]
        if let at = memo.at {
            let clock = Calendar.current.dateComponents([.hour, .minute], from: at)
            let time = String(format: "%d:%02d", clock.hour ?? 0, clock.minute ?? 0)
            parts.append(String(localized: "\(DateWords.monthDay(CalendarDate(at))) \(time) · 달력으로"))
        } else if let due = memo.due {
            parts.append(String(localized: "\(DateWords.monthDay(due)) · 달력으로"))
        }
        if let place = memo.place { parts.append("@" + place) }
        if let line = receipt?.line() { parts.append(line) }
        return parts.joined(separator: " · ")
    }
}

/// 「오늘 뭐 있어」 — 「지금」의 카드를 읽어 준다. 앱과 위젯이 보는 그 세 장(`Recall.nowCards`).
struct TodayIntent: AppIntent {
    static let title: LocalizedStringResource = "오늘 뭐 있어"
    static let description = IntentDescription("「지금」의 카드를 읽어 줍니다 — 오늘 다시 볼 것·오늘 일정·고정한 메모.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let paths = try await IntentVault.paths()
        let memos = ((try? await MemoVault(paths: paths).loadAll()) ?? []).map(\.memo)
        let now = Date()
        let cards = WidgetAgenda.nowCards(memos, now: now, seen: NowSeen.load())
        guard !cards.isEmpty else { return .result(dialog: "지금 펼칠 것이 없어요.") }
        let lines = cards.map { "\(NowBand.reasonText($0, now: now)) — \($0.memo.title)" }
        return .result(dialog: IntentDialog("\(lines.joined(separator: "\n"))"))
    }
}

/// 「펜」 — 앱을 열고 펜에 키보드를 올린다. 말로 적기보다 손으로 적고 싶을 때의 액션 버튼.
struct OpenPenIntent: AppIntent {
    static let title: LocalizedStringResource = "펜 올리기"
    static let description = IntentDescription("앱을 열고 바로 적을 수 있게 펜에 키보드를 올립니다.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppLinks.shared.requestWrite()
        return .result()
    }
}

/// Siri 가 알아듣는 말과 단축어 앱의 타일 — 앱을 깔면 바로 선다, 등록할 것이 없다.
struct LazyMemoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WriteMemoIntent(),
            phrases: [
                "\(.applicationName)에 적기", "\(.applicationName)에 메모", "\(.applicationName)에 적어 줘",
            ],
            shortTitle: "적기",
            systemImageName: "pencil.line"
        )
        AppShortcut(
            intent: TodayIntent(),
            phrases: ["\(.applicationName) 오늘 뭐 있어", "\(.applicationName)에서 오늘 뭐 있는지"],
            shortTitle: "오늘",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: OpenPenIntent(),
            phrases: ["\(.applicationName) 펜", "\(.applicationName) 펜 열어 줘"],
            shortTitle: "펜",
            systemImageName: "keyboard"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}

/// 인텐트가 메모를 적는 자리 — 앱(`AppModel.start`)·공유 시트와 같은 차례: iCloud 컨테이너, 없으면 App Group.
enum IntentVault {
    static func paths() async throws -> AppPaths {
        // 컨테이너 찾기는 첫 호출에 iCloud 데몬과 이야기하는 막히는 호출이다.
        let container = await Task.detached(priority: .userInitiated) { AppPaths.ubiquityContainer() }.value
        let paths = AppPaths.resolveCloud(container: container, shared: AppPaths.sharedContainer()).paths
        try paths.createDirectories()
        return paths
    }
}
