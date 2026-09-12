import Foundation

/// 파일 시스템 레이아웃 (설계문서 §5.1).
///
/// **정본은 Vault 안의 마크다운뿐이다.** `support` 아래는 전부 파생물이라
/// 통째로 지워도 Vault 만 있으면 재생성된다 — 이 불변식이 D4 의 근거다.
public struct AppPaths: Sendable, Equatable {
    /// 정본 저장소. 사용자가 Finder 로 열 수 있어야 하고, 통째로 iCloud Drive 에
    /// 옮기는 것만으로 동기화가 해결되어야 한다.
    public let vault: URL
    /// 파생 데이터. 지워도 무방하다.
    public let support: URL

    public init(vault: URL, support: URL) {
        self.vault = vault
        self.support = support
    }

    // MARK: 정본

    /// `notes/2026/08/<ulid>.md` — 연/월 디렉터리는 저장 시점에 만든다.
    public var notes: URL { vault.appending(path: "notes", directoryHint: .isDirectory) }
    /// 삭제된 메모의 보존 장소. 하드 삭제는 여기서만 일어난다 (D6).
    public var trash: URL { vault.appending(path: ".trash", directoryHint: .isDirectory) }

    // MARK: 파생

    public var index: URL { support.appending(path: "index.sqlite", directoryHint: .notDirectory) }
    /// 창 위치·크기·디스플레이. 정본 파일에 섞지 않는다 (설계문서 §5.1).
    public var layout: URL { support.appending(path: "layout.json", directoryHint: .notDirectory) }
    public var settings: URL { support.appending(path: "settings.json", directoryHint: .notDirectory) }
    /// 빠른 입력이 들고 있던 글 (`CaptureDraftStore`). 메모가 아니라 초안이라
    /// 정본에 두지 않는다 — 확정하는 순간 없어진다.
    public var captureDraft: URL { support.appending(path: "capture-draft.txt", directoryHint: .notDirectory) }

    // MARK: 생성

    public static let bundleIdentifier = "io.github.bunhine0452.lazymemo"
    public static let vaultFolderName = "lazymemo"

    /// 테스트·검증용 위치 재지정. 실제 메모를 건드리지 않고 앱을 띄울 수 있다.
    public static let vaultEnvironmentKey = "LAZYMEMO_VAULT"

    /// 자리를 정한 결과. **못 찾은 폴더를 함께 들고 온다.**
    ///
    /// 옮겨 둔 폴더가 없어졌을 때(외장 디스크를 빼 두었거나 사용자가 지웠거나)
    /// 조용히 기본 자리로 돌아가면 앱은 빈 폴더를 하나 새로 만들고, 사용자가
    /// 보는 것은 **메모가 전부 사라진 화면**이다. 그래서 되돌아왔다는 사실을
    /// 들고 나가 메뉴가 적게 한다 (`MenuBarController`).
    public struct Resolution: Sendable, Equatable {
        public let paths: AppPaths
        /// 설정에 적혀 있었지만 찾지 못한 폴더. 없으면 `nil`.
        public let missingVault: URL?
    }

    /// 기본 위치 — Vault 는 `~/Documents/lazymemo`, 파생물은 Application Support.
    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> AppPaths {
        resolve(environment: environment, fileManager: fileManager).paths
    }

    /// 설정에 적힌 메모 폴더까지 살펴 자리를 정한다 (설계문서 §5.1).
    ///
    /// **파생물 자리는 옮기지 않는다.** 옮기는 것은 정본뿐이라, 설정 파일은
    /// 언제나 같은 곳(Application Support)에서 읽힌다 — 그렇지 않으면 폴더를
    /// 알아야 설정을 읽고 설정을 읽어야 폴더를 아는 고리가 생긴다.
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> Resolution {
        if let override = environment[vaultEnvironmentKey], !override.isEmpty {
            let root = URL(filePath: override, directoryHint: .isDirectory)
            return Resolution(
                paths: AppPaths(
                    vault: root.appending(path: "vault", directoryHint: .isDirectory),
                    support: root.appending(path: "support", directoryHint: .isDirectory)
                ),
                missingVault: nil
            )
        }

        let home = standardHomeLocations(fileManager: fileManager)
        guard let stored = Settings.storedVaultPath(inSupport: home.support) else {
            return Resolution(paths: home, missingVault: nil)
        }

        let moved = URL(filePath: stored, directoryHint: .isDirectory)
        guard isDirectory(moved, fileManager: fileManager) else {
            return Resolution(paths: home, missingVault: moved)
        }
        return Resolution(
            paths: AppPaths(vault: moved, support: home.support), missingVault: nil
        )
    }

    static func isDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        var directory: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: url.path(percentEncoded: false), isDirectory: &directory
        )
        return exists && directory.boolValue
    }

    private static func standardHomeLocations(fileManager: FileManager) -> AppPaths {
        let home = URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
        let documents = (try? fileManager.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )) ?? home.appending(path: "Documents", directoryHint: .isDirectory)
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )) ?? home.appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return AppPaths(
            vault: documents.appending(path: vaultFolderName, directoryHint: .isDirectory),
            support: appSupport.appending(path: vaultFolderName, directoryHint: .isDirectory)
        )
    }

    /// 없는 디렉터리를 만든다. 이미 있으면 아무것도 하지 않는다.
    public func createDirectories(fileManager: FileManager = .default) throws {
        for directory in [vault, notes, trash, support] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// 저장 시점의 연/월로 갈라진 메모 디렉터리. 한 폴더에 수천 개가 쌓이지 않게 한다.
    public func notesDirectory(for date: Date, calendar: Calendar = .current) -> URL {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = String(format: "%04d", parts.year ?? 0)
        let month = String(format: "%02d", parts.month ?? 0)
        return notes
            .appending(path: year, directoryHint: .isDirectory)
            .appending(path: month, directoryHint: .isDirectory)
    }
}
