import Foundation
import SwiftData

/// Adds a profile operation or replaces an unsent/terminal operation in the current transaction.
struct UserProfileOutboxWriter {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func enqueueProfileUpdate(for user: UserEntity, now: Date = Date()) throws {
        let payload = try JSONEncoder().encode(
            UserProfileSyncPayload(selectedProgramID: user.selectedProgramId)
        )

        if let replaceableOperation = try replaceableProfileOperation(for: user.id) {
            replaceableOperation.payload = payload
            replaceableOperation.revision = user.revision
            replaceableOperation.statusRawValue = SyncOperationStatus.pending.rawValue
            replaceableOperation.createdAt = now
            replaceableOperation.attemptCount = 0
            replaceableOperation.nextAttemptAt = nil
            replaceableOperation.lastErrorMessage = nil
            return
        }

        context.insert(
            SyncOperationEntity(
                userId: user.id,
                aggregateTypeRawValue: SyncAggregateType.userProfile.rawValue,
                aggregateId: user.id,
                mutationRawValue: SyncMutation.update.rawValue,
                payload: payload,
                revision: user.revision,
                createdAt: now
            )
        )
    }

    private func replaceableProfileOperation(for userID: UUID) throws -> SyncOperationEntity? {
        let pendingStatus = SyncOperationStatus.pending.rawValue
        let failedStatus = SyncOperationStatus.failed.rawValue
        let profileType = SyncAggregateType.userProfile.rawValue
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate {
                $0.userId == userID
                    && $0.aggregateTypeRawValue == profileType
                    && (
                        $0.statusRawValue == pendingStatus
                            || $0.statusRawValue == failedStatus
                    )
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let operations = try context.fetch(descriptor)
        if let pendingOperation = operations.first(where: {
            $0.statusRawValue == pendingStatus
        }) {
            operations
                .filter { $0.statusRawValue == failedStatus }
                .forEach(context.delete)
            return pendingOperation
        }

        guard let failedOperation = operations.first else { return nil }
        operations.dropFirst().forEach(context.delete)
        return failedOperation
    }
}
