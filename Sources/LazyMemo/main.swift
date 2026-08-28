import AppKit
import LazyMemoUI

// SwiftUI 의 @main App 대신 AppKit 진입점을 직접 연다.
// 메모당 NSWindow(D2)와 바탕화면 창 레벨을 다루려면 NSApplication 을
// 직접 소유해야 하고, SwiftUI 의 WindowGroup 생명주기는 그 경로를 막는다.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
