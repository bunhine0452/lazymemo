import Foundation
import Observation

/// 위젯이 두드린 「적기」(`lazymemo://write`)를 펜이 읽을 자리에 담아 둔다.
///
/// 앱이 꺼진 채 눌렀을 때 화면이 아직 없어서 여기 담는다 — `SpotlightCenter.opened` 와
/// 같은 결. 메모를 여는 주소(`lazymemo://memo/<id>`)는 그 자리를 그대로 쓴다: 어디서
/// 왔든 「그 메모」이고 `HomeView` 가 알림·검색과 같은 시트로 연다 (`AppModel.open(url:)`).
/// 펜은 `PenBar` 가 읽는다 — 서 있으면 바로, 아직 없으면 서는 순간.
@MainActor @Observable
final class AppLinks {
    static let shared = AppLinks()

    /// 펜을 올려 달라는 요청이 기다리고 있다.
    private(set) var pendingWrite = false

    func requestWrite() { pendingWrite = true }

    /// 받아 가면 비운다 — 탭을 옮겨 펜이 다시 서도 두 번 올라오지 않게.
    func takeWrite() -> Bool {
        defer { pendingWrite = false }
        return pendingWrite
    }
}
