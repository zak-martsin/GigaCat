import Foundation
import Testing
@testable import GigaCat

/// Verifies that the mock data layer behaves like a coherent offline-first repository boundary.
struct MockRepositoryTests {

    @Test
    func selectedProgramUpdatePersistsInStore() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockUserRepository(store: store)
        let originalUser = try #require(await store.currentUser())
        let program = try #require(await store.programs().first)

        let updatedUser = try await repository.updateSelectedProgram(for: originalUser.id, programId: program.id)

        #expect(updatedUser.selectedProgramId == program.id)
        #expect(await store.currentUser()?.selectedProgramId == program.id)
    }

    @Test
    func workoutDaysAreReturnedInPlannedOrder() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutProgramRepository(store: store)
        let programID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))

        let days = try await repository.fetchWorkoutDays(programId: programID)

        #expect(days.map(\.title) == ["Push", "Pull", "Arms & Delts"])
    }

    @Test
    func startingSecondActiveSessionFails() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutRepository(store: store)
        let user = try #require(await store.currentUser())
        let selectedProgramID = try #require(user.selectedProgramId)
        let firstDay = try #require(await store.workoutDays(programId: selectedProgramID).first)

        await #expect(throws: RepositoryError.activeSessionAlreadyExists) {
            try await repository.startSession(
                userId: user.id,
                workoutDayId: firstDay.id,
                startedAt: Date()
            )
        }
    }

    @Test
    func latestExerciseLogUsesNewestUserLogAcrossWorkoutDays() async throws {
        let fixture = try LatestExerciseLogFixture()
        let repository = MockWorkoutRepository(store: fixture.store)

        let latestLog = try await repository.fetchLatestExerciseLog(
            userId: fixture.user.id,
            exerciseId: fixture.exercise.id
        )

        #expect(latestLog == fixture.expectedLog)
    }

    @Test
    func completingSessionAndSelectingProgramIsAtomicWhenProgramIsMissing() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutRepository(store: store)
        let user = try #require(await store.currentUser())
        let activeSession = try #require(await store.activeSession(for: user.id))
        let originalSelectedProgramID = user.selectedProgramId
        let missingProgramID = UUID()

        await #expect(throws: RepositoryError.workoutProgramNotFound) {
            try await repository.completeSessionAndSelectProgram(
                sessionId: activeSession.id,
                completedAt: Date(),
                userId: user.id,
                programId: missingProgramID
            )
        }

        let unchangedUser = try #require(await store.currentUser())
        let unchangedSession = try #require(await store.activeSession(for: user.id))

        #expect(unchangedUser.selectedProgramId == originalSelectedProgramID)
        #expect(unchangedSession.id == activeSession.id)
        #expect(unchangedSession.status == .inProgress)
    }

    @Test
    func sessionCompletionPercentageTracksRepeatedExerciseBlocksIndependently() throws {
        let workoutDayID = UUID()
        let repeatedExerciseID = UUID()

        let plannedExercises = [
            try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: repeatedExerciseID,
                targetSets: 3,
                targetReps: 10,
                orderIndex: 0
            ),
            try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: repeatedExerciseID,
                targetSets: 2,
                targetReps: 12,
                orderIndex: 1
            )
        ]

        let logs = try makeLogs(plannedExercises: plannedExercises)

        let completionPercentage = HomePresentationService.completionPercentage(
            plannedExercises: plannedExercises,
            logs: logs
        )

        #expect(completionPercentage == 100)
    }

    /// Creates duplicate and repeated set logs so completion calculations can prove they deduplicate by set number.
    private func makeLogs(plannedExercises: [WorkoutDayExercise])throws -> [ExerciseLog] {
        let sessionID = UUID()

      return try [
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[0].id,
                weight: 0,
                reps: 10,
                setNumber: 1
            ),
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[0].id,
                weight: 0,
                reps: 10,
                setNumber: 2
            ),
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[0].id,
                weight: 0,
                reps: 10,
                setNumber: 3
            ),
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[1].id,
                weight: 0,
                reps: 12,
                setNumber: 1
            ),
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[1].id,
                weight: 0,
                reps: 12,
                setNumber: 2
            ),
            ExerciseLog(
                sessionId: sessionID,
                workoutDayExerciseId: plannedExercises[1].id,
                weight: 0,
                reps: 12,
                setNumber: 2
            )
        ]
    }

    @Test
    func nextWorkoutDayUsesMostRecentlyCompletedSession() throws {
        let firstDayID = UUID()
        let secondDayID = UUID()
        let thirdDayID = UUID()
        let days = [
            try WorkoutDay(id: firstDayID, programId: UUID(), title: "Day 1", orderIndex: 0),
            try WorkoutDay(id: secondDayID, programId: UUID(), title: "Day 2", orderIndex: 1),
            try WorkoutDay(id: thirdDayID, programId: UUID(), title: "Day 3", orderIndex: 2)
        ]

        let olderStartedLater = try WorkoutSession(
            userId: UUID(),
            workoutDayId: secondDayID,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 2_000),
            completedAt: Date(timeIntervalSince1970: 2_100)
        )
        let newerCompletedLater = try WorkoutSession(
            userId: UUID(),
            workoutDayId: firstDayID,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 3_000)
        )

        let sortedByCompletedAt = [olderStartedLater, newerCompletedLater].sorted { lhs, rhs in
            let lhsCompletedAt = lhs.completedAt ?? lhs.startedAt
            let rhsCompletedAt = rhs.completedAt ?? rhs.startedAt

            if lhsCompletedAt == rhsCompletedAt {
                return lhs.startedAt > rhs.startedAt
            }

            return lhsCompletedAt > rhsCompletedAt
        }

        let nextDay = HomePresentationService.nextWorkoutDay(
            days: days,
            completedSessions: sortedByCompletedAt
        )

        #expect(nextDay?.id == secondDayID)
    }
}

private extension MockRepositoryTests {
    struct LatestExerciseLogFixture {
        let store: MockDataStore
        let user: User
        let exercise: Exercise
        let expectedLog: ExerciseLog

        init() throws {
            let content = try LatestExerciseContent()
            let history = try LatestExerciseHistory(content: content)

            store = MockDataStore(
                users: [history.user, history.otherUser],
                workoutDays: [content.firstDay, content.secondDay],
                dayExercises: [content.firstDayExercise, content.secondDayExercise],
                exercises: [content.exercise],
                sessions: [history.previousSession, history.currentSession, history.otherUserSession],
                exerciseLogs: [history.previousLog, history.expectedLog, history.otherUserLog],
                currentUserID: history.user.id
            )
            user = history.user
            exercise = content.exercise
            expectedLog = history.expectedLog
        }
    }

    struct LatestExerciseContent {
        let firstDay: WorkoutDay
        let secondDay: WorkoutDay
        let exercise: Exercise
        let firstDayExercise: WorkoutDayExercise
        let secondDayExercise: WorkoutDayExercise

        init() throws {
            let programID = UUID()
            firstDay = try WorkoutDay(programId: programID, title: "First Day", orderIndex: 0)
            secondDay = try WorkoutDay(programId: programID, title: "Second Day", orderIndex: 1)
            exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
            firstDayExercise = try WorkoutDayExercise(
                workoutDayId: firstDay.id,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )
            secondDayExercise = try WorkoutDayExercise(
                workoutDayId: secondDay.id,
                exerciseId: exercise.id,
                targetSets: 4,
                targetReps: 6,
                orderIndex: 0
            )
        }
    }

    struct LatestExerciseHistory {
        let user: User
        let otherUser: User
        let previousSession: WorkoutSession
        let currentSession: WorkoutSession
        let otherUserSession: WorkoutSession
        let previousLog: ExerciseLog
        let expectedLog: ExerciseLog
        let otherUserLog: ExerciseLog

        init(content: LatestExerciseContent) throws {
            user = try User(appleUserId: "latest-log-user")
            otherUser = try User(appleUserId: "other-latest-log-user")
            previousSession = try WorkoutSession(
                userId: user.id,
                workoutDayId: content.firstDay.id,
                status: .completed,
                startedAt: Date(timeIntervalSince1970: 500),
                completedAt: Date(timeIntervalSince1970: 1_000)
            )
            currentSession = try WorkoutSession(
                userId: user.id,
                workoutDayId: content.secondDay.id,
                startedAt: Date(timeIntervalSince1970: 1_500)
            )
            otherUserSession = try WorkoutSession(
                userId: otherUser.id,
                workoutDayId: content.secondDay.id,
                startedAt: Date(timeIntervalSince1970: 2_500)
            )
            previousLog = try ExerciseLog(
                sessionId: previousSession.id,
                workoutDayExerciseId: content.firstDayExercise.id,
                weight: 55,
                reps: 8,
                setNumber: 1,
                performedAt: Date(timeIntervalSince1970: 900)
            )
            expectedLog = try ExerciseLog(
                sessionId: currentSession.id,
                workoutDayExerciseId: content.secondDayExercise.id,
                weight: 62.5,
                reps: 6,
                setNumber: 1,
                performedAt: Date(timeIntervalSince1970: 2_000)
            )
            otherUserLog = try ExerciseLog(
                sessionId: otherUserSession.id,
                workoutDayExerciseId: content.secondDayExercise.id,
                weight: 100,
                reps: 3,
                setNumber: 1,
                performedAt: Date(timeIntervalSince1970: 3_000)
            )
        }
    }
}
