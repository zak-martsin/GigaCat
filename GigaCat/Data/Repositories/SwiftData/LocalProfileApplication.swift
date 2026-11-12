import Foundation
import SwiftData

/// One commit boundary for local edits, remote pulls, acknowledgements and explicit failure recovery.
struct LocalProfileApplication {
    let context: ModelContext

    @discardableResult
    func apply(
        _ profile: User,
        to existing: UserEntity?,
        enqueueLocalChange: Bool = false,
        removing operations: [SyncOperationEntity] = []
    ) throws -> Bool {
        let current = existing.map(UserMapper.toDomain)
        let didChange = current != profile
        guard didChange || !operations.isEmpty else { return false }
        let userID = profile.id
        let activeStatus = WorkoutSessionStatus.inProgress.rawValue
        let trainingChanged = current?.goal != profile.goal || current?.level != profile.level
        let sessions = trainingChanged ? try context.fetch(FetchDescriptor<WorkoutSessionEntity>(predicate: #Predicate {
            $0.userId == userID && $0.statusRawValue == activeStatus
        })) : []
        let targets = try sessions.map { session in
            let resolved = try LocalWorkoutTargetStore(context: context).resolved(session, user: current ?? profile)
            return WorkoutTargetResolver().recalculated(resolved.exerciseTargets ?? [], user: profile)
        }
        let checkpoint = try LocalProfileWriteCheckpoint(user: existing, userID: userID, sessions: sessions, context: context)
        let entity = existing ?? UserMapper.toEntity(profile)
        do {
            if existing == nil { context.insert(entity) }
            UserMapper.update(entity, from: profile)
            for (session, snapshot) in zip(sessions, targets) { session.exerciseTargets = snapshot }
            if enqueueLocalChange {
                entity.revision += 1
                try UserProfileOutboxWriter(context: context).enqueueProfileUpdate(for: entity)
            }
            operations.forEach(context.delete)
            try context.save()
        } catch {
            try checkpoint.restore(user: entity, context: context)
            throw error
        }
        return didChange
    }
}
