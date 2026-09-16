import Foundation

/// 「어디서 출발하시나요?」를 **물을 만한 메모인가**, 그리고 앱 밖에서 적힌 메모가 그 질문을 앱에 남기는 길.
///
/// 공유 시트(폰)는 파일 한 장만 떨구고 나온다 (`InboxDrop`) — 거기엔 비서도 펜도 없다. 그래서 물을
/// 만한 약속을 적으면 ① 알림 하나를 걸어 「어디서 출발하시나요? 눌러서 답해 주세요」라 말하고,
/// ② 앱 그룹 폴더에 그 메모의 id 를 적어 둔다. 앱이 켜지면(알림을 눌렀든 아니든) 그 id 를 거둬
/// 펜에 질문을 세운다 (`RoutePlanner.begin`). 알림 권한이 없으면 ②만 남는다.
public enum RouteAsk {
    /// 앞으로 올 약속이고, 자리(좌표·이름·지도 링크)가 있으며, 아직 길이 적히지 않았다.
    public static func applies(_ memo: Memo, now: Date = Date()) -> Bool {
        guard let at = memo.at, at > now, memo.deleted == nil, !RouteNote.contains(memo.body) else { return false }
        if memo.geo != nil || memo.place?.isEmpty == false { return true }
        return MarkdownScanner.linkDestinations(in: memo.body).contains(where: MapLink.isMap)
    }

    /// 알림의 id 머리 — 다시 보기 알림(`recall.`)과 갈린다.
    public static let notificationPrefix = "route-ask."
    /// 알림 `userInfo` 의 열쇠 — 값이 `route` 면 누를 때 편집 화면이 아니라 펜의 질문이 선다.
    public static let askKey = "ask"
    public static let askValue = "route"

    public static let question = "어디서 출발하시나요?"
    public static let notificationBody = "어디서 출발하시나요? 눌러서 답하면 가는 길을 찾아 적어 둘게요."

    // MARK: 앱 밖에서 남기는 표

    private static let markerName = "route-ask.json"

    private static func marker(in group: URL) -> URL {
        group.appending(path: markerName, directoryHint: .notDirectory)
    }

    /// 앱이 켜지면 물어봐 달라고 적어 둔다. 같은 id 는 한 번만.
    public static func remember(_ id: ULID, in group: URL?) {
        guard let group else { return }
        var ids = pending(in: group)
        guard !ids.contains(id.stringValue) else { return }
        ids.append(id.stringValue)
        write(ids, to: marker(in: group))
    }

    /// 적어 둔 것을 전부 거두고 비운다 — 늦게 적힌 것이 뒤에 온다.
    public static func takePending(in group: URL?) -> [ULID] {
        guard let group else { return [] }
        let ids = pending(in: group).compactMap(ULID.init)
        try? FileManager.default.removeItem(at: marker(in: group))
        return ids
    }

    private static func pending(in group: URL) -> [String] {
        guard let data = try? Data(contentsOf: marker(in: group)),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids
    }

    private static func write(_ ids: [String], to location: URL) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        try? data.write(to: location, options: .atomic)
    }
}
