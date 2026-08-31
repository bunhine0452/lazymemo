import Foundation
import LazyMemoCore

/// 처음 켰을 때 바탕화면에 이미 놓여 있는 종이.
///
/// 이 앱은 메뉴바 아이콘 하나가 전부라, 단축키를 모르면 **앱이 있다는 것조차
/// 모른다.** 그렇다고 온보딩 화면을 지으면 "앱은 자기를 드러내지 않는다"
/// (철학 4)가 첫 화면에서 깨진다.
///
/// 그래서 안내서를 앱이 아니라 **메모로** 준다. 이 앱이 무엇을 하는 물건인지
/// 그 물건 자체로 보여 주고, 다 읽으면 그냥 지우면 된다 — 지우는 법까지
/// 그 종이 안에 적혀 있으므로 읽는 것과 배우는 것이 한 번에 끝난다.
///
/// 체크상자를 쓴 것도 같은 이유다. 눌러서 뒤집히는 것을 손으로 겪어 보는 것이
/// "체크상자를 누르면 됩니다" 라고 적는 것보다 짧다.
enum WelcomeNote {
    /// 첫 장의 글. 짧아야 한다 — 긴 안내는 안 읽히고, 안 읽히는 안내는 없는 것과 같다.
    static let body = """
        여기 적으면 됩니다

        - [ ] ⌥⌘N 을 눌러 한 줄 적어 보기
        - [ ] 「내일 3시 치과」라고 적어 보기 — 달력이 받습니다
        - [ ] 이 줄을 눌러 체크해 보기

        저장 버튼은 없습니다. 치는 대로 남습니다.

        메뉴바 아이콘을 **오른쪽 버튼**으로 누르면 메모 목록·달력·설정이 있고,
        「로그인할 때 시작」을 켜 두면 껐다 켜도 이 종이들이 그대로 떠 있습니다.

        이 종이는 지워도 됩니다 — 포인터를 올리면 왼쪽 위에 휴지통이 뜹니다.
        """

    /// 지금 인사할 자리인가.
    ///
    /// 두 가지를 **함께** 본다. 인사한 적이 없고(`greeted`), 메모도 하나 없을 때만.
    /// 설정 파일은 파생물이라 지워질 수 있는데(§5.1), 그때 쓰던 사람에게 안내
    /// 종이가 한 장 더 생기면 그건 안내가 아니라 치울 거리다.
    static func shouldGreet(greeted: Bool?, memoCount: Int) -> Bool {
        greeted != true && memoCount == 0
    }

    /// 첫 장을 놓는다. 이미 놓았으면 아무 일도 하지 않는다.
    ///
    /// 인사했다는 사실은 **종이를 만들기 전에** 적는다. 만들다 실패했을 때
    /// 다음 실행에서 또 시도하면, 실패가 이어지는 동안 켤 때마다 종이가 한
    /// 장씩 쌓일 수 있다.
    @MainActor
    static func place(in store: MemoStore, settings: SettingsStore) async {
        guard shouldGreet(greeted: settings.current.greeted, memoCount: store.memos.count) else {
            return
        }
        settings.update { $0.greeted = true }
        _ = try? await store.create(body: body, color: .yellow)
    }
}
