import CoreGraphics
import Testing
@testable import LazyMemoUI

/// 끌어다 놓기가 한 칸씩 밀리는 사고는 화면에서 안 보인다 — 놓고 나서
/// 하루 어긋난 것을 다음 날 알게 된다. 그래서 좌표를 못 박는다.
@Suite("MonthGridGeometry")
struct MonthGridGeometryTests {
    /// 폭 280, 한 주 32pt, 6주. 실제 창(300pt · 좌우 여백 14pt)과 같은 모양이다.
    private let grid = MonthGridGeometry(
        frame: CGRect(x: 14, y: 100, width: 280, height: 192),
        rows: 6
    )

    @Test("첫 칸의 한가운데는 0번이다")
    func findsFirstCell() {
        #expect(grid.index(at: CGPoint(x: 34, y: 116)) == 0)
    }

    @Test("칸 번호는 왼쪽에서 오른쪽, 위에서 아래로 센다")
    func countsRowMajor() {
        // 셋째 열(인덱스 2), 둘째 줄 → 7 + 2
        #expect(grid.index(at: CGPoint(x: 14 + 40 * 2 + 20, y: 100 + 32 + 16)) == 9)
        // 마지막 칸
        #expect(grid.index(at: CGPoint(x: 293, y: 291)) == 41)
    }

    @Test("격자 밖은 놓을 곳이 없다")
    func rejectsOutside() {
        #expect(grid.index(at: CGPoint(x: 13, y: 116)) == nil)
        #expect(grid.index(at: CGPoint(x: 294, y: 116)) == nil)
        #expect(grid.index(at: CGPoint(x: 34, y: 99)) == nil)
        #expect(grid.index(at: CGPoint(x: 34, y: 292)) == nil)
    }

    @Test("칸 경계는 다음 칸의 첫 점이다")
    func splitsOnBoundary() {
        #expect(grid.index(at: CGPoint(x: 53.9, y: 116)) == 0)
        #expect(grid.index(at: CGPoint(x: 54, y: 116)) == 1)
        #expect(grid.index(at: CGPoint(x: 34, y: 131.9)) == 0)
        #expect(grid.index(at: CGPoint(x: 34, y: 132)) == 7)
    }

    @Test("칸의 자리를 되물으면 그 칸 안의 점이 다시 그 칸으로 돌아온다")
    func roundTripsThroughFrames() {
        for index in 0..<42 {
            let frame = grid.frame(of: index)
            #expect(frame != nil)
            #expect(grid.index(at: CGPoint(x: frame!.midX, y: frame!.midY)) == index)
        }
        #expect(grid.frame(of: 42) == nil)
        #expect(grid.frame(of: -1) == nil)
    }

    @Test("아직 재지 않은 격자에는 아무것도 놓이지 않는다")
    func handlesUnmeasuredGrid() {
        let empty = MonthGridGeometry(frame: .zero, rows: 0)
        #expect(empty.index(at: .zero) == nil)
        #expect(empty.cellSize == .zero)
    }
}
