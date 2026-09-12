import Foundation
import LazyMemoCore
import Testing
@testable import LazyMemoUI

/// 사라진 메모의 좌표는 지우되 **한 박자 안 보인 것은 봐준다** (`NoteWindowManager.staleLayouts`).
///
/// 여러 장이 한꺼번에 들어오는 도중 파일 감시가 발화하면 아직 다 쓰이지 않은
/// 파일은 목록에서 잠깐 빠진다. 그때 좌표를 지우면 그 메모가 돌아왔을 때
/// «치워 둔 것» 이라는 사실이 함께 사라져 서랍에 있어야 할 종이가 바탕화면에 선다.
@Suite("좌표 정리에는 유예가 있다")
struct LayoutPruneTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("처음 안 보인 좌표는 지우지 않고 기억만 한다")
    func firstAbsenceIsForgiven() {
        let gone = ULID()
        let verdict = NoteWindowManager.staleLayouts(
            known: [gone], alive: [], absentSince: [:], now: base
        )
        #expect(verdict.drop.isEmpty)
        #expect(verdict.absentSince[gone] == base)
    }

    @Test("유예를 넘겨서도 안 보이면 그때 지운다")
    func absenceBeyondGraceIsPruned() {
        let gone = ULID()
        let later = base.addingTimeInterval(NoteWindowManager.pruneGrace + 1)
        let verdict = NoteWindowManager.staleLayouts(
            known: [gone], alive: [], absentSince: [gone: base], now: later
        )
        #expect(verdict.drop == [gone])
        #expect(verdict.absentSince.isEmpty)
    }

    @Test("도로 보이면 기억을 지운다 — 다음에 또 잠깐 빠져도 처음부터 센다")
    func reappearanceResetsTheClock() {
        let back = ULID()
        let verdict = NoteWindowManager.staleLayouts(
            known: [back], alive: [back], absentSince: [back: base], now: base.addingTimeInterval(5)
        )
        #expect(verdict.drop.isEmpty)
        #expect(verdict.absentSince.isEmpty)
    }

    @Test("살아 있는 메모의 좌표는 언제나 남는다")
    func aliveLayoutsAreNeverDropped() {
        let alive = ULID()
        let verdict = NoteWindowManager.staleLayouts(
            known: [alive], alive: [alive], absentSince: [:],
            now: base.addingTimeInterval(1000)
        )
        #expect(verdict.drop.isEmpty)
    }
}
