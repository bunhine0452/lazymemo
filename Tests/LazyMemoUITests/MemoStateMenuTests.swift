import Foundation
import Testing
@testable import LazyMemoCore
@testable import LazyMemoUI

/// 맥 화면이 처리 상태(완료·보관)를 어디에 세우는가 — 창 없이 서는 규칙만 (인계서 묶음 4).
///
/// 메뉴 자체는 시스템 창이라 여기서 못 짓는다 — 그쪽은 `scripts/verify-state.sh` 가 실제 앱으로 잰다.
/// 여기서 못 박는 것은 종이·서랍이 보관한 것과 끝낸 것을 **어디에** 두는가다: 보관한 종이가 바탕화면에도
/// 서랍에도 없으면 그것은 사람 눈에 「없어졌다」다.
@MainActor
@Suite("처리 상태 — 종이와 서랍의 자리")
struct MemoStateMenuTests {
    @Test("보관한 종이는 서랍에 있다 — 치워 둔 것과 같은 자리, 지운 것은 아니다")
    func archivedSitsInTheDrawer() {
        let plain = Memo(body: "그냥 글")
        let archived = Memo(body: "넣어 둔 글", archived: Date())
        let tidied = Memo(body: "- [x] 끝", tidied: Date())
        let dated = Memo(due: CalendarDate(year: 2026, month: 9, day: 30), body: "일정", archived: Date())
        var deleted = Memo(body: "지운 글", archived: Date()); deleted.deleted = Date()

        #expect(!DrawerContents.holds(plain, putAway: false))
        #expect(DrawerContents.holds(archived, putAway: false))
        #expect(DrawerContents.holds(tidied, putAway: false))
        #expect(!DrawerContents.holds(dated, putAway: false), "날짜가 붙은 것은 달력이 맡는다")
        #expect(!DrawerContents.holds(deleted, putAway: false), "휴지통은 D6 이 맡는다")
    }

    @Test("끝낸 종이에는 꼬리가 선다 — 「완료」가 적힐 자리")
    func doneShowsInTheFooter() {
        #expect(!NoteFooter.isVisible(for: Memo(body: "그냥 글")))
        #expect(NoteFooter.isVisible(for: Memo(body: "그냥 글", done: Date())))
    }

    @Test("바탕화면에 서는 것 — 보관한 것은 치워 둔 것처럼 서지 않는다")
    func archivedDoesNotStandOnTheDesktop() {
        // `NoteWindowManager.plannedVisibleMemos` 가 보는 값과 같다.
        #expect(Memo(body: "글", archived: Date()).isPutAway)
        #expect(Memo(body: "글", tidied: Date()).isPutAway)
        #expect(!Memo(body: "글", done: Date()).isPutAway, "끝낸 것은 사흘 동안 그대로 서 있다")
    }
}
