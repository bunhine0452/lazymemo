#if os(iOS)
import AppIntents
import Foundation
import LazyMemoCore
import LazyMemoWidgetsCore

/// 「봤어요」 — 홈 화면에서 바로 카드를 내려놓는다. **앱을 열지 않는다.**
///
/// 지난 시각의 카드는 놓친 사람을 위해 남지만 본 사람에게는 치울 거리다 (`NowBand`). 앱에서는
/// 카드 위의 단추 하나였는데 위젯에서는 앱을 열고 목록을 지나야 닿았다 — 「지금」을 보는 자리와
/// 내려놓는 자리가 다르면 그건 위젯이 아니라 앱의 광고다.
///
/// 내려놓은 것은 **이 기기의 defaults** 에만 적는다 (`NowSeen`, App Group). 메모 파일은 건드리지
/// 않는다: 확장은 파일만 읽고(`WidgetVault`) 인덱스·첨부·되풀이의 규칙은 앱이 든다. 같은 이유로
/// 「하루 미루기」는 위젯에 두지 않았다 — 그것은 `at`·`due` 를 고쳐 파일에 되쓰는 일이다.
///
/// `perform()` 이 돌아오면 시스템이 이 위젯의 시간표를 다시 부른다 ("When you return from the
/// perform() function, the system reloads the widget's timeline using its timeline provider") —
/// 그래서 여기서 굳이 `WidgetCenter` 를 부르지 않는다. 앱은 앞으로 나올 때 다시 읽는다
/// (`StackView` 의 `didBecomeActive`).
///
/// 맥에는 없다. 맥 위젯에는 App Group entitlement 가 없어 `NowSeen` 이 확장 제 집의 defaults 로
/// 떨어지고, 그러면 눌러도 앱의 띠는 그대로다 — 아무 일도 안 하는 단추를 두느니 두지 않는다.
struct SeenIntent: AppIntent {
    static let title: LocalizedStringResource = "봤어요"
    static var description: IntentDescription { IntentDescription("「지금」에서 이 카드를 내려놓습니다.") }

    /// 어느 메모인가 (ULID).
    @Parameter(title: "메모") var memo: String
    /// 그 등장의 이름표 — 시각을 미루거나 날이 바뀌면 다시 오른다 (`Recall.Card.stamp`).
    @Parameter(title: "이름표") var stamp: Double

    init() {}

    init(id: ULID, stamp: Date) {
        self.memo = id.description
        self.stamp = stamp.timeIntervalSince1970
    }

    func perform() async throws -> some IntentResult {
        guard let id = ULID(memo) else { return .result() }
        NowSeen.putDown(id, stamp: Date(timeIntervalSince1970: stamp))
        return .result()
    }
}
#endif
