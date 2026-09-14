import AppKit
import LazyMemoUI

// App Store 판의 진입점 — Sources/LazyMemo/main.swift 와 같다. 다른 것은 껍데기다:
// Xcode 가 서명·샌드박스·프로비저닝을 붙이고, Info.plist(Config/Mac-Info.plist)가
// 이 판이 스토어 판임을 말한다 (`LazyMemoAppStoreBuild`).
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
