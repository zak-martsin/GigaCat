import Foundation
import SwiftData

/// Resolves snapshots on the shared context; callers persist them in their lifecycle transaction.
struct LocalWorkoutTargetStore {
    let context: ModelContext

    func initialTargets(workoutDayID: UUID, user: User, includeInactive: Bool = false) throws -> [WorkoutExerciseTarget] {
        let descriptor = FetchDescriptor<WorkoutDayExerciseEntity>(predicate: #Predicate {
            $0.workoutDayId == workoutDayID && (includeInactive || $0.isActive)
        })
        let exercises = try context.fetch(descriptor).map(WorkoutDayExerciseMapper.toDomain)
        return WorkoutTargetResolver().targets(exercises: exercises, user: user)
    }

    /// Only legacy active sessions need catalog lookup. Completed history is never backfilled.
    func resolved(_ entity: WorkoutSessionEntity, user: User) throws -> WorkoutSession {
        let session = try WorkoutSessionMapper.toDomain(entity)
        guard session.isActive, session.exerciseTargets == nil else { return session }
        return try session.replacingTargets(initialTargets(
            workoutDayID: session.workoutDayId, user: user, includeInactive: true
        ))
    }
}
