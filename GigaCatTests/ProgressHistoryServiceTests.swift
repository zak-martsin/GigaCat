import Foundation
import Testing
@testable import GigaCat

struct ProgressHistoryServiceTests {

    @Test
    func loadsOnlyCompletedSessionsWithPerformedExercisesAndOrderedSets() async throws {
        let fixture = try Fixture()

        let context = try await fixture.service.loadHistory()

        #expect(context.userID == fixture.user.id)
        #expect(context.sessions.map(\.session.id) == [fixture.completedSession.id])

        let sessionHistory = try #require(context.sessions.first)
        #expect(sessionHistory.workoutDay == fixture.workoutDay)
        #expect(sessionHistory.exercises.map(\.exercise.id) == [
            fixture.firstExercise.id,
            fixture.secondExercise.id
        ])
        #expect(sessionHistory.exercises[0].logs.map(\.setNumber) == [1, 2])
        #expect(sessionHistory.exercises[1].logs.map(\.setNumber) == [1])
    }

    @Test
    func missingCurrentUserProducesFeatureSpecificError() async throws {
        let store = MockDataStore()
        let factory = MockRepositoryFactory(store: store)
        let service = ProgressHistoryService(
            userRepository: factory.userRepository,
            workoutRepository: factory.workoutRepository,
            workoutProgramRepository: factory.workoutProgramRepository
        )

        await #expect(throws: ProgressHistoryError.currentUserNotFound) {
            try await service.loadHistory()
        }
    }
}

private extension ProgressHistoryServiceTests {
    struct ExercisePlan {
        let firstExercise: Exercise
        let secondExercise: Exercise
        let firstDayExercise: WorkoutDayExercise
        let secondDayExercise: WorkoutDayExercise
        let exercises: [Exercise]
        let dayExercises: [WorkoutDayExercise]
    }

    struct Fixture {
        let user: User
        let workoutDay: WorkoutDay
        let firstExercise: Exercise
        let secondExercise: Exercise
        let completedSession: WorkoutSession
        let service: ProgressHistoryService

        init() throws {
            let now = Date(timeIntervalSince1970: 20_000)
            let programID = UUID()
            user = try User(
                appleUserId: "progress-history-user",
                createdAt: now.addingTimeInterval(-10_000),
                updatedAt: now
            )
            workoutDay = try WorkoutDay(
                programId: programID,
                title: "Push",
                orderIndex: 0
            )
            let exercisePlan = try Self.makeExercisePlan(workoutDayID: workoutDay.id)
            firstExercise = exercisePlan.firstExercise
            secondExercise = exercisePlan.secondExercise
            completedSession = try WorkoutSession(
                userId: user.id,
                workoutDayId: workoutDay.id,
                status: .completed,
                startedAt: now.addingTimeInterval(-7_200),
                completedAt: now.addingTimeInterval(-3_600)
            )
            let activeSession = try WorkoutSession(
                userId: user.id,
                workoutDayId: workoutDay.id,
                startedAt: now
            )
            let logs = try Self.makeLogs(
                sessionID: completedSession.id,
                firstDayExerciseID: exercisePlan.firstDayExercise.id,
                secondDayExerciseID: exercisePlan.secondDayExercise.id,
                now: now
            )
            let store = MockDataStore(
                users: [user],
                workoutDays: [workoutDay],
                dayExercises: exercisePlan.dayExercises,
                exercises: exercisePlan.exercises,
                sessions: [activeSession, completedSession],
                exerciseLogs: logs,
                currentUserID: user.id
            )
            let factory = MockRepositoryFactory(store: store)
            service = ProgressHistoryService(
                userRepository: factory.userRepository,
                workoutRepository: factory.workoutRepository,
                workoutProgramRepository: factory.workoutProgramRepository
            )
        }

        private static func makeExercisePlan(
            workoutDayID: UUID
        ) throws -> ExercisePlan {
            let firstExercise = try Exercise(
                name: "Bench Press",
                muscleGroup: .chest
            )
            let secondExercise = try Exercise(
                name: "Shoulder Press",
                muscleGroup: .shoulders
            )
            let exerciseWithoutLogs = try Exercise(
                name: "Triceps Extension",
                muscleGroup: .triceps
            )
            let firstDayExercise = try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: firstExercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )
            let secondDayExercise = try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: secondExercise.id,
                targetSets: 3,
                targetReps: 10,
                orderIndex: 1
            )
            let unperformedDayExercise = try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: exerciseWithoutLogs.id,
                targetSets: 3,
                targetReps: 12,
                orderIndex: 2
            )

            return ExercisePlan(
                firstExercise: firstExercise,
                secondExercise: secondExercise,
                firstDayExercise: firstDayExercise,
                secondDayExercise: secondDayExercise,
                exercises: [firstExercise, secondExercise, exerciseWithoutLogs],
                dayExercises: [firstDayExercise, secondDayExercise, unperformedDayExercise]
            )
        }

        private static func makeLogs(
            sessionID: UUID,
            firstDayExerciseID: UUID,
            secondDayExerciseID: UUID,
            now: Date
        ) throws -> [ExerciseLog] {
            [
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: firstDayExerciseID,
                    weight: 80,
                    reps: 8,
                    setNumber: 2,
                    performedAt: now.addingTimeInterval(-6_000)
                ),
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: secondDayExerciseID,
                    weight: 40,
                    reps: 10,
                    setNumber: 1,
                    performedAt: now.addingTimeInterval(-5_500)
                ),
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: firstDayExerciseID,
                    weight: 80,
                    reps: 8,
                    setNumber: 1,
                    performedAt: now.addingTimeInterval(-6_500)
                )
            ]
        }
    }
}
