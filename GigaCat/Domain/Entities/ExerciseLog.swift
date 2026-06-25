import Foundation

/// Single performed set recorded for an exercise within a workout session.
struct ExerciseLog: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let weight: Double
    let reps: Int
    let setNumber: Int

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        exerciseId: UUID,
        weight: Double,
        reps: Int,
        setNumber: Int
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
        self.exerciseId = exerciseId
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
    }
}
