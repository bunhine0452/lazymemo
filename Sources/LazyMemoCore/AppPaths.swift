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

    // MARK: 생성

    public static let bundleIdentifier = "io.github.bunhine0452.lazymemo"
    public static let vaultFolderName = "lazymemo"

    /// 테스트·검증용 위치 재지정. 실제 메모를 건드리지 않고 앱을 띄울 수 있다.
    public static let vaultEnvironmentKey = "LAZYMEMO_VAULT"

    /// 기본 위치 — Vault 는 `~/Documents/lazymemo`, 파생물은 Application Support.
    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> AppPaths {
        if let override = environment[vaultEnvironmentKey], !override.isEmpty {
            let root = URL(filePath: override, directoryHint: .isDirectory)
            return AppPaths(
                vault: root.appending(path: "vault", directoryHint: .isDirectory),
                support: root.appending(path: "support", directoryHint: .isDirectory)
            )
        }
        return standardHomeLocations(fileManager: fileManager)
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
