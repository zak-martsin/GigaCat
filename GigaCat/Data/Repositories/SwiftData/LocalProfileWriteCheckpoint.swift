import Foundation
import SwiftData

/// Restores in-memory aggregate state when a failed SwiftData save has already advanced its change tracking.
/// A store-level failed transaction stays atomic; rollback alone does not reliably reset registered objects.
struct LocalProfileWriteCheckpoint {
    private let user: User?
    private let userID: UUID
    private let revision: Int
    private let sessionTargets: [(WorkoutSessionEntity, [WorkoutExerciseTarget]?)]
    private let operations: [ProfileOperationCheckpoint]

    init(user: UserEntity, sessions: [WorkoutSessionEntity], context: ModelContext) throws {
        try self.init(user: user, userID: user.id, sessions: sessions, context: context)
    }

    init(user: UserEntity?, userID: UUID, sessions: [WorkoutSessionEntity], context: ModelContext) throws {
        self.user = user.map(UserMapper.toDomain)
        self.userID = userID
        revision = user?.revision ?? 0
        sessionTargets = sessions.map { ($0, $0.exerciseTargets) }
        let userID = self.userID
        let profileType = SyncAggregateType.userProfile.rawValue
        operations = try context.fetch(FetchDescriptor<SyncOperationEntity>(predicate: #Predicate {
            $0.userId == userID && $0.aggregateTypeRawValue == profileType
        })).map(ProfileOperationCheckpoint.init)
    }

    func restore(user entity: UserEntity, context: ModelContext) throws {
        context.rollback()
        if let user {
            UserMapper.update(entity, from: user)
            entity.revision = revision
        } else {
            context.delete(entity)
        }
        for (session, targets) in sessionTargets { session.exerciseTargets = targets }
        let userID = self.userID
        let profileType = SyncAggregateType.userProfile.rawValue
        let current = try context.fetch(FetchDescriptor<SyncOperationEntity>(predicate: #Predicate {
            $0.userId == userID && $0.aggregateTypeRawValue == profileType
        }))
        let originalIDs = Set(operations.map(\.id))
        for operation in current where !originalIDs.contains(operation.id) { context.delete(operation) }
        for snapshot in operations {
            if let operation = current.first(where: { $0.id == snapshot.id }) {
                snapshot.restore(operation)
            } else {
                // Reuse the registered identity: cloning a failed deletion duplicates the stored row in fetches.
                context.insert(snapshot.original)
                snapshot.restore(snapshot.original)
            }
        }
        context.processPendingChanges()
    }
}

private struct ProfileOperationCheckpoint {
    let original: SyncOperationEntity
    let id: UUID
    let userID: UUID
    let aggregateType: String
    let aggregateID: UUID
    let mutation: String
    let payload: Data
    let revision: Int
    let status: String
    let createdAt: Date
    let attemptCount: Int
    let nextAttemptAt: Date?
    let lastErrorMessage: String?

    init(_ entity: SyncOperationEntity) {
        original = entity
        id = entity.id
        userID = entity.userId
        aggregateType = entity.aggregateTypeRawValue
        aggregateID = entity.aggregateId
        mutation = entity.mutationRawValue
        payload = entity.payload
        revision = entity.revision
        status = entity.statusRawValue
        createdAt = entity.createdAt
        attemptCount = entity.attemptCount
        nextAttemptAt = entity.nextAttemptAt
        lastErrorMessage = entity.lastErrorMessage
    }

    func restore(_ entity: SyncOperationEntity) {
        entity.payload = payload
        entity.revision = revision
        entity.statusRawValue = status
        entity.createdAt = createdAt
        entity.attemptCount = attemptCount
        entity.nextAttemptAt = nextAttemptAt
        entity.lastErrorMessage = lastErrorMessage
    }

}
