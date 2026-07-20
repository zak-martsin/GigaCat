import Foundation

/// Single performed set recorded for a planned workout day exercise within a workout session.
struct ExerciseLog: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sessionId: UUID
    let workoutDayExerciseId: UUID
    let weight: Double
    let reps: Int
    let setNumber: Int
    let performedAt: Date

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        workoutDayExerciseId: UUID,
        weight: Double,
        reps: Int,
        setNumber: Int,
        performedAt: Date = Date()
    ) throws {
        guard weight >= 0 else {
            throw DomainValidationError.negativeValue(field: "weight")
        }

        guard reps > 0 else {
            throw DomainValidationError.nonPositiveValue(field: "reps")
        }

        guard setNumber > 0 else {
            throw DomainValidationError.nonPositiveValue(field: "setNumber")
        }

        self.id = id
        self.sessionId = sessionId
        self.workoutDayExerciseId = workoutDayExerciseId
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
        self.performedAt = performedAt
    }
}

/// Values entered for one performed set before a workout session has been resolved.
struct WorkoutSetInput: Equatable, Sendable {
    let userId: UUID
    let workoutDayId: UUID
    let workoutDayExerciseId: UUID
    let weight: Double
    let reps: Int
    let setNumber: Int
    let performedAt: Date
}

/// Persisted set together with the session state produced by the save operation.
struct WorkoutSetSaveResult: Equatable, Sendable {
    let session: WorkoutSession
    let log: ExerciseLog
    let didStartSession: Bool
}
