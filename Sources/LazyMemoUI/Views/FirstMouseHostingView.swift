import AppKit
import SwiftUI

/// 첫 클릭을 삼키지 않는 호스팅 뷰.
///
/// 바탕화면에 놓인 종이는 **다른 앱을 쓰다가 바로 손이 간다.** 그때 기본
/// 동작대로라면 첫 클릭은 앱을 활성화하는 데만 쓰이고 사라진다 — 사용자에게는
/// "한 번 눌렀는데 아무 일도 안 일어났다" 로 보이고, 두 번 눌러야 써지는
/// 메모지는 종이가 아니라 대화상자다.
///
/// 텍스트 뷰는 자기 몫을 스스로 열지만(`MemoNSTextView`), 겹쳐 뜨는 조작
/// 버튼과 「흐름」의 화살표는 SwiftUI 가 이 뷰 안에서 직접 처리하므로
/// 여기서 열어 주어야 한다.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) 는 쓰지 않는다")
    }
}
