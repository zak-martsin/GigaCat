import Foundation
import SwiftData

/// SwiftData-backed outbox used exclusively by the synchronization layer.
@MainActor
final class LocalSyncOutboxRepository: SyncOutboxRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recoverInterruptedOperations(for userID: UUID) throws {
        let syncingStatus = SyncOperationStatus.syncing.rawValue
        let operations = try operations(for: userID).filter {
            $0.statusRawValue == syncingStatus
        }

        guard !operations.isEmpty else { return }

        operations.forEach {
            $0.statusRawValue = SyncOperationStatus.pending.rawValue
            $0.nextAttemptAt = nil
        }
        try context.save()
    }

    func claimNextReadyOperation(
        for userID: UUID,
        now: Date
    ) throws -> SyncOperation? {
        let pendingStatus = SyncOperationStatus.pending.rawValue
        guard let entity = try operations(for: userID).first(where: {
            $0.statusRawValue == pendingStatus
                && ($0.nextAttemptAt.map { $0 <= now } ?? true)
        }) else {
            return nil
        }

        entity.statusRawValue = SyncOperationStatus.syncing.rawValue
        try context.save()
        return try operation(from: entity)
    }

    func complete(
        _ operation: SyncOperation,
        with result: SyncExecutionResult
    ) throws {
        guard let entity = try findOperation(id: operation.id) else { return }

        switch result {
        case .userProfile(let remoteProfile):
            guard operation.aggregateType == .userProfile,
                  remoteProfile.id == operation.aggregateID else {
                throw SyncError.unsupportedOperation
            }

            if let user = try findUser(id: remoteProfile.id),
               user.revision == operation.revision {
                user.selectedProgramId = remoteProfile.selectedProgramId
                user.createdAt = remoteProfile.createdAt
                user.updatedAt = remoteProfile.updatedAt
            }
        }

        context.delete(entity)
        try context.save()
    }

    func fail(
        _ operation: SyncOperation,
        message: String,
        retryAt: Date
    ) throws {
        guard let entity = try findOperation(id: operation.id) else { return }

        if try hasNewerProfileOperation(than: operation) {
            context.delete(entity)
        } else {
            entity.statusRawValue = SyncOperationStatus.pending.rawValue
            entity.attemptCount += 1
            entity.nextAttemptAt = retryAt
            entity.lastErrorMessage = message
        }

        try context.save()
    }

    func failPermanently(_ operation: SyncOperation, message: String) throws {
        guard let entity = try findOperation(id: operation.id) else { return }

        entity.statusRawValue = SyncOperationStatus.failed.rawValue
        entity.attemptCount += 1
        entity.nextAttemptAt = nil
        entity.lastErrorMessage = message
        try context.save()
    }

    func hasReadyOperations(for userID: UUID, now: Date) throws -> Bool {
        let pendingStatus = SyncOperationStatus.pending.rawValue
        return try operations(for: userID).contains {
            $0.statusRawValue == pendingStatus
                && ($0.nextAttemptAt.map { $0 <= now } ?? true)
        }
    }

    func nextRetryDate(for userID: UUID, after date: Date) throws -> Date? {
        let pendingStatus = SyncOperationStatus.pending.rawValue
        return try operations(for: userID)
            .filter {
                $0.statusRawValue == pendingStatus
                    && ($0.nextAttemptAt ?? .distantPast) > date
            }
            .compactMap(\.nextAttemptAt)
            .min()
    }

    func hasUnfinishedProfileOperation(for userID: UUID) throws -> Bool {
        let profileType = SyncAggregateType.userProfile.rawValue
        return try operations(for: userID).contains {
            $0.aggregateTypeRawValue == profileType
        }
    }

    func operationCount(for userID: UUID) throws -> Int {
        try operations(for: userID).count
    }

    private func operations(for userID: UUID) throws -> [SyncOperationEntity] {
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate {
                $0.userId == userID
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    private func findOperation(id: UUID) throws -> SyncOperationEntity? {
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        return try context.fetch(descriptor).first
    }

    private func findUser(id: UUID) throws -> UserEntity? {
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        return try context.fetch(descriptor).first
    }

    private func hasNewerProfileOperation(than operation: SyncOperation) throws -> Bool {
        guard operation.aggregateType == .userProfile else { return false }

        let profileType = SyncAggregateType.userProfile.rawValue
        return try operations(for: operation.userID).contains {
            $0.id != operation.id
                && $0.aggregateTypeRawValue == profileType
                && $0.aggregateId == operation.aggregateID
                && $0.revision > operation.revision
        }
    }

    private func operation(from entity: SyncOperationEntity) throws -> SyncOperation {
        guard let aggregateType = SyncAggregateType(rawValue: entity.aggregateTypeRawValue),
              let mutation = SyncMutation(rawValue: entity.mutationRawValue),
              let status = SyncOperationStatus(rawValue: entity.statusRawValue) else {
            throw SyncError.invalidStoredOperation
        }

        return SyncOperation(
            id: entity.id,
            userID: entity.userId,
            aggregateType: aggregateType,
            aggregateID: entity.aggregateId,
            mutation: mutation,
            payload: entity.payload,
            revision: entity.revision,
            status: status,
            createdAt: entity.createdAt,
            attemptCount: entity.attemptCount,
            nextAttemptAt: entity.nextAttemptAt
        )
    }
}
