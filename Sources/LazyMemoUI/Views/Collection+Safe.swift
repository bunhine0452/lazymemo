import Foundation

extension Collection {
    /// 범위를 벗어나면 nil. 측정 통계처럼 표본 수가 보장되지 않는 곳에서 쓴다.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
