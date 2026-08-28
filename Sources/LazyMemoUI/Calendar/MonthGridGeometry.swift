import CoreGraphics

/// 달 격자의 좌표 계산 — "포인터가 지금 몇 일 칸 위에 있는가".
///
/// 끌어서 옮기기는 이 한 줄에 전부 걸려 있다. 칸마다 `GeometryReader` 를 심어
/// 자리를 물어보는 방법도 있지만, 그러면 화면에 42개가 더 생긴다 (설계문서
/// §14.8 — 레이어 수가 곧 메모리 예산이다). 격자는 어차피 균일하므로 **산수로
/// 풀면 뷰 하나로 끝난다.**
///
/// 그리고 산수는 눈으로 확인할 수 없다 — 한 칸 밀린 것과 맞는 것이 화면에서
/// 똑같아 보인다. `LineMarker` 에서 세 번 틀렸던 것이 정확히 이런 종류였다.
/// 그래서 뷰 밖의 순수 값으로 빼서 테스트로 못 박는다.
struct MonthGridGeometry: Equatable {
    /// 한 주는 일곱 칸. 주 시작 요일을 바꿔도 이것은 변하지 않는다.
    static let columns = 7

    /// 격자가 차지한 자리 (SwiftUI 좌표 — y 는 아래로 자란다).
    var frame: CGRect
    /// 주 수. 달에 따라 5주도 6주도 된다.
    var rows: Int

    var cellSize: CGSize {
        guard rows > 0 else { return .zero }
        return CGSize(
            width: frame.width / CGFloat(Self.columns),
            height: frame.height / CGFloat(rows)
        )
    }

    /// 포인터 아래의 칸 번호. 격자 밖이면 `nil` — 놓을 곳이 없다는 뜻이다.
    ///
    /// 오른쪽·아래 모서리는 다음 칸이 아니라 **밖**으로 친다. 안 그러면
    /// 마지막 열에서 손가락 하나 차이로 존재하지 않는 8번째 칸이 나온다.
    func index(at point: CGPoint) -> Int? {
        guard rows > 0, frame.width > 0, frame.height > 0 else { return nil }
        guard point.x >= frame.minX, point.x < frame.maxX,
              point.y >= frame.minY, point.y < frame.maxY
        else { return nil }

        let column = Int((point.x - frame.minX) / cellSize.width)
        let row = Int((point.y - frame.minY) / cellSize.height)
        // 부동소수 나눗셈이 경계에서 한 칸 넘길 수 있다. 마지막 칸으로 잡아 둔다.
        let safeColumn = min(column, Self.columns - 1)
        let safeRow = min(row, rows - 1)
        return safeRow * Self.columns + safeColumn
    }

    /// 칸 번호가 차지한 자리. 끌고 있는 동안 목표 칸을 밝히는 데 쓴다.
    func frame(of index: Int) -> CGRect? {
        guard rows > 0, index >= 0, index < rows * Self.columns else { return nil }
        let column = index % Self.columns
        let row = index / Self.columns
        return CGRect(
            x: frame.minX + CGFloat(column) * cellSize.width,
            y: frame.minY + CGFloat(row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
    }
}
