import Foundation
import LazyMemoCore

/// 메모 폴더를 사람 말로. 메뉴의 「지금은 …」 과 옮기기 대화 상자가 같이 쓴다.
///
/// 홈 아래는 `~` 로 줄인다 — 메뉴 한 줄에 전체 경로는 안 들어간다. **샌드박스
/// 안에서는 `NSHomeDirectory()` 가 컨테이너를 가리켜** 컨테이너 안의 폴더가
/// `~/Documents/lazymemo` 로 보이는데, 그 자리는 Finder 에서 그렇게 안 보인다.
/// 그래서 두 컨테이너는 이름으로 적고, 줄이는 기준은 진짜 홈으로 잡는다.
enum VaultLabel {
    static func readable(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let cloudFolder = AppPaths.ubiquityContainerIdentifier.replacingOccurrences(of: ".", with: "~")
        if path.contains("/Library/Mobile Documents/\(cloudFolder)/Documents") {
            return L("iCloud Drive 의 LazyMemo 폴더")
        }
        if path.contains("/Library/Containers/\(AppPaths.bundleIdentifier)/") {
            return L("이 앱의 보관함 — iCloud 가 꺼져 있을 때의 자리")
        }
        let home = realHome
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// 샌드박스가 바꿔치기하기 전의 홈.
    private static var realHome: String {
        if let directory = getpwuid(getuid())?.pointee.pw_dir {
            return String(cString: directory)
        }
        return NSHomeDirectory()
    }
}
