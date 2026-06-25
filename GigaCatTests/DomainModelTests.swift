import Foundation
import Testing
@testable import GigaCat

/// Coverage for the main domain invariants that should stay stable across data-layer changes.
struct DomainModelTests {

    @Test
    func workoutSessionCanBeCompleted() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let completedAt = Date(timeIntervalSince1970: 1_600)
        let session = try WorkoutSession(
            userId: UUID(),
            workoutDayId: UUID(),
            startedAt: startedAt
        )

        let completedSession = try session.markCompleted(at: completedAt)

        #expect(completedSession.status == .completed)
        #expect(completedSession.completedAt == completedAt)
        #expect(completedSession.isActive == false)
    }

    @Test
    func completedWorkoutSessionCanNotBeCompletedAgain() throws {
        let session = try WorkoutSession(
            userId: UUID(),
            workoutDayId: UUID(),
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_500)
        )

        #expect(throws: DomainValidationError.invalidSessionTransition) {
            try session.markCompleted(at: Date(timeIntervalSince1970: 1_800))
        }
    }

    @Test
    func exerciseLogRejectsInvalidValues() {
        #expect(throws: DomainValidationError.nonPositiveValue(field: "reps")) {
            try ExerciseLog(
                sessionId: UUID(),
                exerciseId: UUID(),
                weight: 40,
                reps: 0,
                setNumber: 1
            )
        }
    }

    @Test
    func workoutDayExerciseAllowsOptionalTargetWeight() throws {
        let assignment = try WorkoutDayExercise(
            workoutDayId: UUID(),
            exerciseId: UUID(),
            targetSets: 4,
            targetReps: 10,
            orderIndex: 1
        )

        #expect(assignment.targetWeight == nil)
    }
}
