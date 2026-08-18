import Foundation
import SwiftData

/// Adds or coalesces a pending profile operation in the caller's current transaction.
struct UserProfileOutboxWriter {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func enqueueProfileUpdate(for user: UserEntity, now: Date = Date()) throws {
        let payload = try JSONEncoder().encode(
            UserProfileSyncPayload(selectedProgramID: user.selectedProgramId)
        )

        if let pendingOperation = try pendingProfileOperation(for: user.id) {
            pendingOperation.payload = payload
            pendingOperation.revision = user.revision
            pendingOperation.createdAt = now
            pendingOperation.attemptCount = 0
            pendingOperation.nextAttemptAt = nil
            pendingOperation.lastErrorMessage = nil
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

    private func pendingProfileOperation(for userID: UUID) throws -> SyncOperationEntity? {
        let pendingStatus = SyncOperationStatus.pending.rawValue
        let profileType = SyncAggregateType.userProfile.rawValue
        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate {
                $0.userId == userID
                    && $0.aggregateTypeRawValue == profileType
                    && $0.statusRawValue == pendingStatus
            }
        )
        return try context.fetch(descriptor).first
    }
}
