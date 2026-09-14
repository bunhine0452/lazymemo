import Foundation

/// 앱이 아닌 곳에서 파일 한 장을 떨군다 — 공유 확장, 앞으로는 위젯.
///
/// `MemoService` 를 띄우지 않는다. 그쪽은 인덱스(SQLite)까지 열고, 인덱스는
/// 파생물이라 **앱이 짓는 것**이다 (§5.3). 확장은 메모리 한도가 빡빡하고 몇
/// 초 안에 끝나야 하므로 정본 한 장만 쓰고 나온다. 앱이 다음에 켜지거나 파일
/// 감시가 발화하면 `reconcile` 이 그 파일을 인덱스에 올린다 — 단축어가 떨군
/// 파일이 지나는 길과 같다.
///
/// 읽는 규칙은 다른 문과 하나다 (`NoteReader`): `내일 3시` 는 일정, `@강남역` 은 장소.
public enum InboxDrop {
    @discardableResult
    public static func drop(
        _ inbound: InboundNote, into paths: AppPaths, now: Date = Date()
    ) async throws -> Memo {
        let note = NoteReader.read(inbound, now: now)
        let memo = Memo(
            id: ULID(timestamp: now), created: now, updated: now,
            due: note.due, at: note.at, every: note.every, place: note.place, geo: note.geo, body: note.body
        )
        try paths.createDirectories()
        try await MemoVault(paths: paths).save(memo)
        return memo
    }
}
