import Foundation

/// User-owned workout execution record tied to a planned workout day.
struct WorkoutSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let workoutDayId: UUID
    let status: WorkoutSessionStatus
    let startedAt: Date
    let completedAt: Date?
    /// Nil identifies legacy history whose original recommendations were never recorded.
    let exerciseTargets: [WorkoutExerciseTarget]?

    init(
        id: UUID = UUID(),
        userId: UUID,
        workoutDayId: UUID,
        status: WorkoutSessionStatus = .inProgress,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        exerciseTargets: [WorkoutExerciseTarget]? = nil
    ) throws {
        if let completedAt {
            guard completedAt >= startedAt else {
                throw DomainValidationError.invalidCompletionDate
            }

            guard status == .completed else {
                throw DomainValidationError.invalidSessionTransition
            }
        }

        if status == .completed, completedAt == nil {
            throw DomainValidationError.invalidSessionTransition
        }

        if let exerciseTargets {
            guard Set(exerciseTargets.map(\.workoutDayExerciseID)).count == exerciseTargets.count else {
                throw DomainValidationError.duplicateExerciseTarget
            }
            for target in exerciseTargets {
                guard target.targetSets > 0, (target.programOverride ?? 1) > 0 else {
                    throw DomainValidationError.nonPositiveValue(field: "targetSets")
                }
            }
        }

        self.id = id
        self.userId = userId
        self.workoutDayId = workoutDayId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exerciseTargets = exerciseTargets
    }

    // MARK: - Lifecycle

    var isActive: Bool {
        status == .inProgress
    }

    /// Completes an in-progress session and preserves the original identity and start date.
    func markCompleted(at date: Date = Date()) throws -> WorkoutSession {
        guard status == .inProgress else {
            throw DomainValidationError.invalidSessionTransition
        }

        guard date >= startedAt else {
            throw DomainValidationError.invalidCompletionDate
        }

        return try WorkoutSession(
            id: id,
            userId: userId,
            workoutDayId: workoutDayId,
            status: .completed,
            startedAt: startedAt,
            completedAt: date,
            exerciseTargets: exerciseTargets
        )
    }
}

extension WorkoutSession {
    /// Updates the planned workload without changing lifecycle dates or recorded performance.
    func replacingTargets(_ targets: [WorkoutExerciseTarget]) throws -> WorkoutSession {
        guard isActive else { throw DomainValidationError.invalidSessionTransition }
        return try WorkoutSession(
            id: id, userId: userId, workoutDayId: workoutDayId,
            status: status, startedAt: startedAt, completedAt: completedAt,
            exerciseTargets: targets
        )
    }
}
