import Foundation

/// 「이 기기에서 알림 받기」가 켜져 있다는 **표** — 앱 그룹 폴더의 파일.
///
/// 켜짐은 앱의 `UserDefaults` 에 산다 (`ReminderCenter`). 공유 시트는 그 defaults 를 못 보므로, 앱이
/// 켜고 끌 때마다 여기 한 벌 더 적는다. 그래야 시트가 「이 기기가 알림을 받기로 했나」를 알고
/// 그 자리에서 걸 수 있다 — 모르면 「앱을 열면 걸려요」라 적는 수밖에 없다 (`ReservationReceipt.needsApp`).
///
/// `RouteAsk` 의 표와 같은 꼴이다: 그룹 defaults 가 아니라 파일인 이유도 같다 — 시험이 임시 폴더로 대신
/// 세울 수 있고, 지워도 메모는 안 다친다.
public enum RecallSwitch {
    private static let markerName = "recall-enabled"

    private static func marker(in group: URL) -> URL {
        group.appending(path: markerName, directoryHint: .notDirectory)
    }

    /// 켜짐을 적는다. 끄면 표를 지운다 — 표가 있다 = 켜져 있다.
    public static func write(enabled: Bool, in group: URL?) {
        guard let group else { return }
        if enabled {
            try? Data("on".utf8).write(to: marker(in: group), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: marker(in: group))
        }
    }

    /// 이 기기가 알림을 받기로 했나. 폴더를 모르면 「모른다」(`nil`) — 꺼짐과 다르다.
    public static func isEnabled(in group: URL?) -> Bool? {
        guard let group else { return nil }
        return FileManager.default.fileExists(atPath: marker(in: group).path(percentEncoded: false))
    }
}
