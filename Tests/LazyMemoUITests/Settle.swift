import Foundation
import Testing

/// 시간이 아니라 **일어나야 할 일**을 기다린다.
///
/// 빠른 입력의 검색에는 디바운스(120ms)가 걸려 있고 그 뒤에 비동기 조회가
/// 붙는다. 그래서 시험이 300ms 를 자고 결과를 재고 있었는데, **여덟 번에 한 번
/// 꼴로 떨어졌다** — 빌드나 렌더가 함께 도는 동안에는 그 잠이 모자란다.
/// 고정된 잠은 기계가 바쁠 때 그대로 거짓 실패가 되고, 거짓 실패가 한 번
/// 나오면 그 다음부터는 통과했다는 말도 못 믿게 된다.
///
/// 넉넉히 자게 하는 것으로는 못 고친다 — 그건 시험 전체를 느리게 만들면서
/// 확률만 낮출 뿐이다. 기다릴 것이 **무엇인지** 적고, 그것이 되면 즉시 나온다.
@MainActor
func settle(
    _ what: String,
    within limit: Duration = .seconds(3),
    until happened: @MainActor () -> Bool
) async {
    let step = Duration.milliseconds(10)
    var waited = Duration.zero

    while waited < limit {
        if happened() { return }
        try? await Task.sleep(for: step)
        waited += step
    }
    Issue.record("\(limit) 를 기다려도 \(what)")
}
