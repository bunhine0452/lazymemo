import Foundation
import LazyMemoCore

/// 실행 결과 — 되돌리기에 필요한 것을 들고 있다.
public struct ActionReceipt: Sendable, Equatable, Identifiable {
    public var id: UUID { actionID }
    public let actionID: UUID
    public let requestID: AssistantRequest.ID
    public let kind: ActionKind
    /// 변경 전 (createMemo 는 nil).
    public let before: Memo?
    /// 변경 후 (trash 는 휴지통에 든 메모).
    public let after: Memo
}

public enum ActionError: Error, Sendable, Equatable {
    /// ask·none — 실행할 것이 없다.
    case nothingToExecute
    /// 휴지통 이동은 확인 UI 를 거쳐야 한다 (명세 §5).
    case needsConfirmation
    /// 모델이 본 글과 저장 직전의 글이 다르다. 아무것도 쓰지 않았다.
    case memoChanged(ULID)
    case memoMissing(ULID)
    /// 되돌리려는 메모를 그 뒤 사용자가 고쳤다. 덮어쓰지 않는다.
    case undoStale(ULID)

    public var message: String {
        switch self {
        case .nothingToExecute: return "바꿀 것이 없습니다"
        case .needsConfirmation: return "휴지통으로 옮기려면 확인이 필요합니다"
        case .memoChanged: return "그 사이 메모가 바뀌어 적용하지 않았습니다"
        case .memoMissing: return "메모를 찾을 수 없습니다"
        case .undoStale: return "그 뒤에 고친 내용이 있어 되돌리지 않았습니다"
        }
    }
}

/// `ProposedAction` 을 `MemoService` 의 조건부 변경으로 옮긴다. 명세 §5 의 정책이 여기 있다.
///
/// - 요청 하나에 쓰기 하나. 같은 요청을 다시 실행하면 저장하지 않고 앞의 영수증을 돌려준다.
/// - 변경 직전 본문 hash 를 대조한다 — vault 안에서, `await` 없이.
/// - 휴지통 이동은 `confirmedTrash` 가 참일 때만.
/// - 되돌리기도 hash 를 대조한다. 그 뒤 사용자가 고쳤으면 되돌리지 않는다.
public actor ActionExecutor {
    private let service: MemoService
    private var receipts: [AssistantRequest.ID: ActionReceipt] = [:]

    public init(service: MemoService) { self.service = service }

    public func receipt(for requestID: AssistantRequest.ID) -> ActionReceipt? { receipts[requestID] }

    @discardableResult
    public func execute(_ action: ProposedAction, confirmedTrash: Bool = false, now: Date = Date()) async throws -> ActionReceipt {
        if let done = receipts[action.requestID] { return done }
        let receipt: ActionReceipt
        switch action.kind {
        case .ask, .none:
            throw ActionError.nothingToExecute
        case .createMemo:
            let memo = try await service.create(
                body: action.patch.body ?? "",
                due: action.patch.due.value, at: action.patch.at.value,
                surface: action.patch.surface.value, folder: action.patch.folder.value, now: now)
            receipt = ActionReceipt(actionID: action.id, requestID: action.requestID, kind: .createMemo, before: nil, after: memo)
        case .trash:
            guard confirmedTrash else { throw ActionError.needsConfirmation }
            guard let id = action.memoID else { throw ActionError.nothingToExecute }
            let before = try await load(id)
            let after = try await mapping(id) { try await service.delete(id, expectedHash: action.expectedContentHash) }
            receipt = ActionReceipt(actionID: action.id, requestID: action.requestID, kind: .trash, before: before, after: after)
        case .setRecall, .reschedule, .moveToFolder:
            guard let id = action.memoID else { throw ActionError.nothingToExecute }
            let patch = action.patch
            let before = try await load(id)
            let after = try await mapping(id) {
                try await service.modify(id, expectedHash: action.expectedContentHash, now: now) { memo in
                    Self.apply(patch, to: &memo)
                }
            }
            receipt = ActionReceipt(actionID: action.id, requestID: action.requestID, kind: action.kind, before: before, after: after)
        }
        receipts[action.requestID] = receipt
        return receipt
    }

    /// 영수증의 `before` 로 되돌린다. `after` 이후 손댄 흔적이 있으면 `undoStale`.
    @discardableResult
    public func undo(_ receipt: ActionReceipt, now: Date = Date()) async throws -> Memo? {
        defer { receipts[receipt.requestID] = nil }
        switch receipt.kind {
        case .createMemo:
            return try await mapping(receipt.after.id, stale: true) {
                try await service.delete(receipt.after.id, expectedHash: receipt.after.contentHash)
            }
        case .trash:
            return try await service.restore(receipt.after.id)
        case .setRecall, .reschedule, .moveToFolder:
            guard let before = receipt.before else { return nil }
            return try await mapping(before.id, stale: true) {
                try await service.modify(before.id, expectedHash: receipt.after.contentHash, now: now) { memo in
                    memo.body = before.body
                    memo.due = before.due
                    memo.at = before.at
                    memo.surface = before.surface
                    memo.folder = before.folder
                }
            }
        case .ask, .none:
            return nil
        }
    }

    static func apply(_ patch: FieldPatch, to memo: inout Memo) {
        if let body = patch.body { memo.body = body }
        if let due = patch.due.doubleOptional { memo.due = due }
        if let at = patch.at.doubleOptional { memo.at = at }
        if let surface = patch.surface.doubleOptional { memo.surface = surface }
        if let folder = patch.folder.doubleOptional { memo.folder = folder }
    }

    private func load(_ id: ULID) async throws -> Memo {
        do { return try await service.get(id) } catch { throw ActionError.memoMissing(id) }
    }

    private func mapping(_ id: ULID, stale: Bool = false, _ work: () async throws -> Memo) async throws -> Memo {
        do { return try await work() } catch MemoVault.Failure.changed {
            throw stale ? ActionError.undoStale(id) : ActionError.memoChanged(id)
        } catch MemoVault.Failure.notFound {
            throw ActionError.memoMissing(id)
        }
    }
}

extension FieldChange {
    /// createMemo 용 — clear 와 keep 은 둘 다 「없음」.
    var value: Value? { if case .set(let v) = self { return v } else { return nil } }
}
