import Foundation

/// 메모 폴더를 다른 자리로 옮긴다 (설계문서 §5.1).
///
/// README 는 처음부터 "이 폴더를 iCloud Drive 안으로 옮기면 동기화가 된다" 고
/// 적어 두었는데, **앱에는 그 폴더를 따라갈 길이 없었다.** Finder 에서 폴더를
/// 옮긴 사용자가 다음에 앱을 켜면 기본 자리에 빈 폴더가 새로 생기고, 화면에는
/// 메모가 한 장도 없다 — 문서가 시킨 대로 했더니 전부 사라진 것으로 보인다.
///
/// 그래서 길을 하나만 낸다. **폴더를 고르면 앱이 상황을 보고 정한다** —
/// 고른 자리에 이미 메모가 있으면 그것을 쓰고(이미 옮겨 둔 사람), 없으면 지금
/// 것을 그리로 옮긴다(이제 옮기려는 사람). 사용자가 "옮기기" 와 "고르기" 중
/// 무엇을 누를지 먼저 판단하게 하지 않는다.
public enum VaultRelocation {
    /// 고른 자리를 두고 무엇을 할 것인가. **하기 전에 사용자에게 이 말을 보인다.**
    public enum Plan: Sendable, Equatable {
        /// 고른 폴더에 이미 메모가 있다 — 옮기지 않고 그것을 쓴다.
        case adopt(URL)
        /// 지금 폴더를 통째로 그 안으로 옮긴다.
        case move(to: URL)
        /// 이미 그 폴더를 쓰고 있다.
        case alreadyThere
        /// 할 수 없는 자리. 까닭을 그대로 화면에 적는다.
        case refuse(String)
    }

    /// 옮겨 갈 자리의 이름. 고른 폴더가 이미 메모 폴더가 아니면 그 **안에** 만든다 —
    /// 바탕화면을 고른 사람의 바탕화면에 `notes/` 와 `.trash/` 를 쏟지 않는다.
    public static func destination(
        choosing chosen: URL, fileManager: FileManager = .default
    ) -> URL {
        isVault(chosen, fileManager: fileManager) || chosen.lastPathComponent == AppPaths.vaultFolderName
            ? chosen
            : chosen.appending(path: AppPaths.vaultFolderName, directoryHint: .isDirectory)
    }

    /// 메모 폴더로 보이는가 — `notes/` 가 있으면 그렇다.
    ///
    /// 파일이 정본이므로(D4) 폴더의 생김새가 곧 근거다. 설정 파일이나 표식을
    /// 따로 두지 않는다: 사용자가 Finder 로 옮긴 폴더에는 그런 것이 없다.
    public static func isVault(_ url: URL, fileManager: FileManager = .default) -> Bool {
        AppPaths.isDirectory(
            url.appending(path: "notes", directoryHint: .isDirectory), fileManager: fileManager
        )
    }

    /// 고른 자리를 두고 무엇을 할지 정한다. **파일은 건드리지 않는다.**
    public static func plan(
        choosing chosen: URL, current: URL, fileManager: FileManager = .default
    ) -> Plan {
        let target = destination(choosing: chosen, fileManager: fileManager)
        let from = standardized(current)
        let to = standardized(target)

        if from == to { return .alreadyThere }
        // 자기 안으로 옮기면 옮기는 도중에 원본이 사라진다.
        if to.hasPrefix(from + "/") {
            return .refuse("메모 폴더 안으로는 옮길 수 없습니다")
        }
        if isVault(target, fileManager: fileManager) { return .adopt(target) }
        if AppPaths.isDirectory(target, fileManager: fileManager),
           !isEmpty(target, fileManager: fileManager) {
            return .refuse("그 자리에 이미 다른 것이 들어 있습니다")
        }
        guard AppPaths.isDirectory(chosen, fileManager: fileManager) else {
            return .refuse("폴더가 아닙니다")
        }
        return .move(to: target)
    }

    /// 정한 대로 옮긴다. 돌려주는 것은 **이제부터 쓸 폴더**다.
    ///
    /// 옮기기는 `moveItem` 한 번이다. 볼륨이 달라 그대로 못 옮기면 Foundation 이
    /// 복사한 뒤 지우는 길로 알아서 넘어가고, 어느 쪽이든 실패하면 원본은
    /// 제자리에 남는다 — 반쯤 옮겨진 상태로 끝나지 않는 것이 여기서 가장 중요하다.
    @discardableResult
    public static func perform(
        _ plan: Plan, from current: URL, fileManager: FileManager = .default
    ) throws -> URL {
        switch plan {
        case .alreadyThere:
            return current
        case .adopt(let target):
            return target
        case .refuse(let reason):
            throw RelocationError.refused(reason)
        case .move(let target):
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            // 빈 껍데기가 먼저 만들어져 있으면(고른 폴더를 방금 새로 만든 경우)
            // `moveItem` 이 거부한다. 비어 있을 때만 치운다.
            if AppPaths.isDirectory(target, fileManager: fileManager),
               isEmpty(target, fileManager: fileManager) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.moveItem(at: current, to: target)
            return target
        }
    }

    public enum RelocationError: Error, LocalizedError, Equatable {
        case refused(String)

        public var errorDescription: String? {
            switch self {
            case .refused(let reason): reason
            }
        }
    }

    private static func isEmpty(_ url: URL, fileManager: FileManager) -> Bool {
        let contents = (try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false)))
        // `.DS_Store` 하나 때문에 "다른 것이 들어 있다" 고 막지 않는다.
        return (contents ?? []).allSatisfy { $0.hasPrefix(".") }
    }

    /// 견줄 수 있는 한 가지 모양으로. 디렉터리 URL 은 끝에 `/` 를 달고 다니는데,
    /// 그 한 글자 때문에 "이 폴더 안인가" 가 언제나 거짓이 된다.
    private static func standardized(_ url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
