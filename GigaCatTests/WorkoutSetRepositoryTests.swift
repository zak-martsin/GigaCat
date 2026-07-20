import Foundation
import Testing
@testable import GigaCat

struct WorkoutSetRepositoryTests {

    @Test
    func firstSetCreatesSessionAtPerformedTime() async throws {
        let fixture = try Fixture()
        let performedAt = Date(timeIntervalSince1970: 1_000)

        let result = try await fixture.repository.saveSet(
            fixture.input(performedAt: performedAt)
        )

        #expect(result.didStartSession)
        #expect(result.session.startedAt == performedAt)
        #expect(result.log.sessionId == result.session.id)
        #expect(await fixture.store.activeSession(for: fixture.user.id) == result.session)
        #expect(await fixture.store.exerciseLogs(sessionId: result.session.id) == [result.log])
    }

    @Test
    func repeatedSetPreservesLogIdentity() async throws {
        let fixture = try Fixture()
        let firstResult = try await fixture.repository.saveSet(
            fixture.input(weight: 60, reps: 8)
        )

        let updatedResult = try await fixture.repository.saveSet(
            fixture.input(weight: 62.5, reps: 7)
        )
        let logs = try await fixture.repository.fetchExerciseLogs(
            sessionId: firstResult.session.id
        )

        #expect(updatedResult.didStartSession == false)
        #expect(updatedResult.log.id == firstResult.log.id)
        #expect(updatedResult.log.weight == 62.5)
        #expect(updatedResult.log.reps == 7)
        #expect(logs == [updatedResult.log])
    }

    @Test
    func invalidFirstSetDoesNotCreateEmptySession() async throws {
        let fixture = try Fixture()

        await #expect(throws: DomainValidationError.nonPositiveValue(field: "reps")) {
            try await fixture.repository.saveSet(fixture.input(reps: 0))
        }

        #expect(await fixture.store.activeSession(for: fixture.user.id) == nil)
        #expect(try await fixture.repository.fetchSessions(for: fixture.user.id).isEmpty)
    }

    @Test
    func setForAnotherDayIsBlockedWhileSessionIsActive() async throws {
        let fixture = try Fixture()
        let firstResult = try await fixture.repository.saveSet(fixture.input())

        await #expect(throws: RepositoryError.activeSessionWorkoutDayConflict) {
            try await fixture.repository.saveSet(fixture.otherDayInput())
        }

        #expect(await fixture.store.activeSession(for: fixture.user.id) == firstResult.session)
        #expect(try await fixture.repository.fetchSessions(for: fixture.user.id).count == 1)
    }
}

private extension WorkoutSetRepositoryTests {
    struct Fixture {
        let user: User
        let day: WorkoutDay
        let dayExercise: WorkoutDayExercise
        let otherDay: WorkoutDay
        let otherDayExercise: WorkoutDayExercise
        let store: MockDataStore
        let repository: MockWorkoutRepository

        init() throws {
            user = try User(appleUserId: "workout-set-user")
            day = try WorkoutDay(programId: UUID(), title: "Day 1", orderIndex: 0)
            otherDay = try WorkoutDay(
                programId: day.programId,
                title: "Day 2",
                orderIndex: 1
            )
            let exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
            let otherExercise = try Exercise(name: "Deadlift", muscleGroup: .fullBody)
            dayExercise = try WorkoutDayExercise(
                workoutDayId: day.id,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )
            otherDayExercise = try WorkoutDayExercise(
                workoutDayId: otherDay.id,
                exerciseId: otherExercise.id,
                targetSets: 3,
                targetReps: 5,
                orderIndex: 0
            )
            store = MockDataStore(
                users: [user],
                workoutDays: [day, otherDay],
                dayExercises: [dayExercise, otherDayExercise],
                exercises: [exercise, otherExercise],
                currentUserID: user.id
            )
            repository = MockWorkoutRepository(store: store)
        }

        func input(
            weight: Double = 60,
            reps: Int = 8,
            performedAt: Date = Date(timeIntervalSince1970: 1_000)
        ) -> WorkoutSetInput {
            WorkoutSetInput(
                userId: user.id,
                workoutDayId: day.id,
                workoutDayExerciseId: dayExercise.id,
                weight: weight,
                reps: reps,
                setNumber: 1,
                performedAt: performedAt
            )
        }

        func otherDayInput() -> WorkoutSetInput {
            WorkoutSetInput(
                userId: user.id,
                workoutDayId: otherDay.id,
                workoutDayExerciseId: otherDayExercise.id,
                weight: 80,
                reps: 5,
                setNumber: 1,
                performedAt: Date(timeIntervalSince1970: 2_000)
            )
        }
    }
}
