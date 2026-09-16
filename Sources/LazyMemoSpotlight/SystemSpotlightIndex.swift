import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// 시스템 색인의 얇은 문. 실제 앱은 `SystemSpotlightIndex`, 시험은 가짜가 선다.
@MainActor public protocol SpotlightIndex: AnyObject {
    /// 이 기기가 지금 색인을 받는가. 못 받으면 올리지 않고 그렇게 적는다.
    var available: Bool { get }
    func index(_ entries: [SpotlightEntry]) async throws
    func remove(ids: [String]) async throws
    /// 이 앱이 올린 것 전부 (`SpotlightEntry.domain`).
    func removeAll() async throws
}

/// `CSSearchableIndex` 위의 문. 앱 번들 안에서만 선다 — bare `swift run`·`swift test` 에는
/// 번들 id 가 없어 시스템이 색인을 받지 않는다.
@MainActor public final class SystemSpotlightIndex: SpotlightIndex {
    public static func ifBundled() -> SystemSpotlightIndex? {
        guard Bundle.main.bundleURL.pathExtension == "app", Bundle.main.bundleIdentifier != nil else { return nil }
        return SystemSpotlightIndex()
    }

    private let index = CSSearchableIndex.default()

    public var available: Bool { CSSearchableIndex.isIndexingAvailable() }

    public func index(_ entries: [SpotlightEntry]) async throws {
        try await index.indexSearchableItems(entries.map(Self.item))
    }

    public func remove(ids: [String]) async throws {
        try await index.deleteSearchableItems(withIdentifiers: ids)
    }

    public func removeAll() async throws {
        try await index.deleteSearchableItems(withDomainIdentifiers: [SpotlightEntry.domain])
    }

    private nonisolated static func item(_ entry: SpotlightEntry) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .plainText)
        attributes.title = entry.title
        attributes.contentDescription = entry.description
        attributes.textContent = entry.text
        attributes.keywords = entry.keywords
        attributes.dueDate = entry.due
        attributes.contentModificationDate = entry.modified
        let item = CSSearchableItem(
            uniqueIdentifier: entry.id, domainIdentifier: SpotlightEntry.domain, attributeSet: attributes
        )
        // 기본은 한 달 뒤 만료다 — 메모는 만료하지 않는다. 내리는 것은 대조가 한다.
        item.expirationDate = .distantFuture
        return item
    }
}
