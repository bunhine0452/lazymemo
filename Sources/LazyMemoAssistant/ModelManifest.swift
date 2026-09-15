import Foundation

/// 내려받을 모델 하나의 정본 — 명세 §7. `main` URL 을 넣지 않는다. revision 과 SHA-256 으로 고정.
public struct ModelManifest: Codable, Sendable, Equatable, Identifiable {
    public var id: String { profileID }
    public let profileID: String
    public let displayName: String
    public let upstreamModelID: String
    public let artifactRepo: String
    public let revision: String
    public let engine: String
    public let file: File
    public let license: String
    public let contextTokens: Int
    public let templateVersion: Int
    /// 시험용 — 파일 URL 등으로 바꿔 끼운다. 출하 manifest 에는 없다.
    public var overrideURL: URL?

    public struct File: Codable, Sendable, Equatable {
        public let name: String
        public let bytes: Int64
        public let sha256: String
        public init(name: String, bytes: Int64, sha256: String) { self.name = name; self.bytes = bytes; self.sha256 = sha256 }
    }

    public init(profileID: String, displayName: String, upstreamModelID: String, artifactRepo: String, revision: String,
                engine: String, file: File, license: String, contextTokens: Int, templateVersion: Int,
                overrideURL: URL? = nil) {
        self.profileID = profileID; self.displayName = displayName; self.upstreamModelID = upstreamModelID
        self.artifactRepo = artifactRepo; self.revision = revision; self.engine = engine; self.file = file
        self.license = license; self.contextTokens = contextTokens; self.templateVersion = templateVersion
        self.overrideURL = overrideURL
    }

    /// 파일 하나만 가리키는 URL — 저장소 전체를 받지 않는다.
    public var downloadURL: URL {
        if let overrideURL { return overrideURL }
        return URL(string: "https://huggingface.co/\(artifactRepo)/resolve/\(revision)/\(file.name)")!
    }

    /// 양 기기 공통 기본. 실기기 게이트(`#model-manifest`) 전까지는 «시작 후보»다.
    public static let gemma4E2B = ModelManifest(
        profileID: "gemma-4-e2b-litert-0.16",
        displayName: "Gemma 4 E2B",
        upstreamModelID: "google/gemma-4-E2B-it",
        artifactRepo: "litert-community/gemma-4-E2B-it-litert-lm",
        revision: "b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1",
        engine: "litert-lm 0.16.0",
        file: File(name: "gemma-4-E2B-it.litertlm", bytes: 2_588_147_712,
                   sha256: "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"),
        license: "Gemma Terms of Use",
        contextTokens: TokenBudget.context,
        templateVersion: 1)
}
