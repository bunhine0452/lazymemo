import SwiftUI
import WidgetKit

/// 홈 화면·잠금 화면·알림 센터의 위젯 셋 — 아이폰과 맥 App Store 판이 같은 확장을 품는다.
///
/// 앱과 같은 파일을 본다(`WidgetVault`) — 인덱스를 열지 않고 마크다운만 읽는다. 무엇을
/// 보이는지는 `LazyMemoWidgetsCore` 가 앱과 같은 규칙으로 정하고(`WidgetAgenda`), 앱이
/// 파일을 바꾸면 `WidgetRefresher` 가 다시 그리게 한다. GitHub 판(SwiftPM 번들)에는
/// 확장이 실리지 않는다 — 스토어 판만의 것이다.
@main
struct LazyMemoWidgets: WidgetBundle {
    var body: some Widget {
        NowWidget()
        NextWidget()
        WriteWidget()
    }
}
