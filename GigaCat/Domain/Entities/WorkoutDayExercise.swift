import Foundation

/// Ordered exercise assignment for a workout day with planned training targets.
struct WorkoutDayExercise: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let workoutDayId: UUID
    let exerciseId: UUID
    let targetSets: Int
    let targetReps: Int
    let targetWeight: Double?
    let orderIndex: Int

    init(
        id: UUID = UUID(),
        workoutDayId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetReps: Int,
        targetWeight: Double? = nil,
        orderIndex: Int
    ) throws {
        guard targetSets > 0 else {
            throw DomainValidationError.nonPositiveValue(field: "targetSets")
        }

        guard targetReps > 0 else {
            throw DomainValidationError.nonPositiveValue(field: "targetReps")
        }

        if let targetWeight, targetWeight < 0 {
            throw DomainValidationError.negativeValue(field: "targetWeight")
        }

        guard orderIndex >= 0 else {
            throw DomainValidationError.negativeValue(field: "orderIndex")
        }

        self.id = id
        self.workoutDayId = workoutDayId
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.orderIndex = orderIndex
    }
}
