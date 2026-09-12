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

    // MARK: iCloud 컨테이너 — 폰과 맥이 같이 보는 자리

    /// 앱 전용 iCloud 컨테이너. 두 앱이 같은 entitlement 로 이 하나를 가리키면
    /// 그 `Documents/` 가 곧 공유 Vault 다 — 백엔드도 계정도 없이 (D4 의 연장).
    ///
    /// 사용자에게는 iCloud Drive 의 「LazyMemo」 폴더로 보인다
    /// (`NSUbiquitousContainerIsDocumentScopePublic`). Finder 로 열어도, 텍스트
    /// 에디터로 고쳐도 된다는 약속은 그대로다.
    public static let ubiquityContainerIdentifier = "iCloud.io.github.bunhine0452.lazymemo"

    /// 컨테이너 안에서 Vault 가 되는 폴더. 컨테이너 자체가 아니라 `Documents/` 인
    /// 이유는 iCloud 가 사용자에게 보여 주는 것이 그 안이기 때문이다 — 그 위에
    /// 두면 파일 앱·Finder 에 나타나지 않는다.
    public static func cloudVault(inContainer container: URL) -> URL {
        container.appending(path: "Documents", directoryHint: .isDirectory)
    }

    /// 이 프로세스가 닿을 수 있는 컨테이너. **막히는 호출이다** — 첫 호출에 iCloud
    /// 데몬과 이야기하므로 메인에서 부르지 말 것.
    ///
    /// entitlement 가 없거나(ad-hoc 빌드) iCloud 가 꺼져 있으면 `nil`. 그때의 폰은
    /// 자기 샌드박스 안 Documents 를 쓰고, 맥은 지금처럼 폴더를 고른다.
    public static func ubiquityContainer(fileManager: FileManager = .default) -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: ubiquityContainerIdentifier)
    }

    /// entitlement 없는 빌드(소스 빌드·ad-hoc)가 컨테이너에 닿는 길. iCloud 는
    /// 컨테이너를 `~/Library/Mobile Documents/` 아래 보통 폴더로 두고, 거기에
    /// 쓰는 것이 누구든 올려 보낸다 — 폰이 한 번 만들어 두면 맥의 어떤 빌드든
    /// 같은 폴더를 본다. **폴더가 있을 때만** 값이 있다. 없는 자리를 가리켜
    /// 빈 폴더를 만들면 iCloud 는 그것을 컨테이너로 치지 않는다.
    public static func cloudContainerOnDisk(
        home: String = NSHomeDirectory(), fileManager: FileManager = .default
    ) -> URL? {
        let folder = ubiquityContainerIdentifier.replacingOccurrences(of: ".", with: "~")
        let url = URL(filePath: home, directoryHint: .isDirectory)
            .appending(path: "Library/Mobile Documents", directoryHint: .isDirectory)
            .appending(path: folder, directoryHint: .isDirectory)
        return isDirectory(url, fileManager: fileManager) ? url : nil
    }

    /// 컨테이너가 있으면 그 `Documents/`, 없으면 기본 자리 — **어느 쪽이었는지를
    /// 함께 들고 나온다.** 조용히 로컬로 떨어지면 사용자는 「맥에 안 나타난다」만
    /// 보고 왜인지는 영영 모른다 (`missingVault` 와 같은 이유).
    ///
    /// `LAZYMEMO_VAULT` 는 여기서도 가장 세다 — 시험·검증이 실제 컨테이너를
    /// 건드리지 않아야 한다.
    public struct CloudResolution: Sendable, Equatable {
        public let paths: AppPaths
        /// 컨테이너를 찾아 그 안을 쓰고 있는가.
        public let usingCloud: Bool
    }

    public static func resolveCloud(
        container: URL?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> CloudResolution {
        let home = resolve(environment: environment, fileManager: fileManager).paths
        if environment[vaultEnvironmentKey]?.isEmpty == false {
            return CloudResolution(paths: home, usingCloud: false)
        }
        guard let container else {
            return CloudResolution(paths: home, usingCloud: false)
        }
        return CloudResolution(
            paths: AppPaths(vault: cloudVault(inContainer: container), support: home.support),
            usingCloud: true
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
