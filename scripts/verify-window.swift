// {#desktop-window} 자동 검증기.
//
// 스크린샷 권한 없이도 창의 존재·레벨·크기를 확인할 수 있다.
// CGWindowListCopyWindowInfo 는 창 "제목"만 화면 기록 권한을 요구하고,
// 기하 정보와 레벨은 권한 없이 읽힌다.
//
//   swift scripts/verify-window.swift <pid>

import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count > 1, let targetPID = Int(arguments[1]) else {
    FileHandle.standardError.write(Data("사용법: swift scripts/verify-window.swift <pid> [--expect N]\n".utf8))
    exit(2)
}

/// 기대하는 바탕화면 레벨 창의 개수. 없으면 "하나라도 있으면 통과".
let expectedCount: Int? = arguments.firstIndex(of: "--expect")
    .flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil }

let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
let expectedLevel = desktopIconLevel + 1

struct WindowInfo {
    let number: Int
    let level: Int
    let bounds: CGRect
    let alpha: Double
}

func onScreenWindows(ownedBy pid: Int) -> [WindowInfo] {
    // ExcludeDesktopElements 를 쓰면 바탕화면 레벨 창이 통째로 빠진다 —
    // 정확히 우리가 찾는 창이므로 옵션 없이 전체를 훑는다.
    let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return raw.compactMap { entry in
        guard entry[kCGWindowOwnerPID as String] as? Int == pid,
              let number = entry[kCGWindowNumber as String] as? Int,
              let level = entry[kCGWindowLayer as String] as? Int,
              let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }
        let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
        return WindowInfo(number: number, level: level, bounds: bounds, alpha: alpha)
    }
}

// 앱이 창을 올릴 때까지 최대 5초 기다린다.
let deadline = Date().addingTimeInterval(5)
var windows: [WindowInfo] = []
repeat {
    windows = onScreenWindows(ownedBy: targetPID)
    let atExpectedLevel = windows.filter { $0.level == expectedLevel }.count
    if atExpectedLevel >= (expectedCount ?? 1) { break }
    Thread.sleep(forTimeInterval: 0.1)
} while Date() < deadline

guard !windows.isEmpty else {
    print("✗ pid \(targetPID) 가 올린 화면 창을 찾지 못했습니다")
    exit(1)
}

// 스크립트가 창 배치를 비교할 수 있도록 기계 판독 형식도 낸다.
if arguments.contains("--json") {
    let matched = windows.filter { $0.level == expectedLevel }
    var payload: [[String: Double]] = []
    for window in matched {
        payload.append([
            "x": Double(window.bounds.origin.x),
            "y": Double(window.bounds.origin.y),
            "w": Double(window.bounds.width),
            "h": Double(window.bounds.height),
        ])
    }
    payload.sort { left, right in
        let leftKey = (left["x"] ?? 0, left["y"] ?? 0)
        let rightKey = (right["x"] ?? 0, right["y"] ?? 0)
        return leftKey < rightKey
    }

    if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) {
        print(text)
    }
    exit(payload.count >= (expectedCount ?? 1) ? 0 : 1)
}

for window in windows {
    print(String(
        format: "  window #%d  level=%d  bounds=(%.0f, %.0f  %.0f×%.0f)  alpha=%.2f",
        window.number, window.level,
        window.bounds.origin.x, window.bounds.origin.y,
        window.bounds.width, window.bounds.height,
        window.alpha
    ))
}

print("")
print("기대 레벨: \(expectedLevel)  (desktopIconWindow \(desktopIconLevel) + 1)")

let matching = windows.filter { $0.level == expectedLevel }.count

if let expectedCount {
    if matching == expectedCount {
        print("✓ 바탕화면 레벨 창 \(matching)개 — 기대와 일치")
        exit(0)
    }
    print("✗ 바탕화면 레벨 창이 \(matching)개입니다 (기대 \(expectedCount)개)")
    exit(1)
}

if matching > 0 {
    print("✓ 바탕화면 레벨 창이 화면에 올라와 있습니다")
    exit(0)
}
print("✗ 기대한 레벨의 창이 없습니다 — 실제 레벨: \(windows.map(\.level))")
exit(1)
