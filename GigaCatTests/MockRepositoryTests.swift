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
    func recentExerciseLogsAreScopedToUserAndOrderedNewestFirst() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutRepository(store: store)
        let user = try #require(await store.currentUser())
        let exerciseID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let exercise = try #require(await store.exercise(id: exerciseID))

        let logs = try await repository.fetchRecentExerciseLogs(
            userId: user.id,
            exerciseId: exercise.id,
            limit: 10
        )

        #expect(logs.count == 2)
        #expect(logs.map(\.setNumber) == [2, 1])
    }

    @Test
    func completedWorkoutSessionRejectsNewLogs() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutRepository(store: store)
        let completedSessionID = try #require(UUID(uuidString: "bcbcbcbc-bcbc-bcbc-bcbc-bcbcbcbcbcbc"))
        let workoutDayExerciseID = try #require(UUID(uuidString: "abababab-abab-abab-abab-abababababab"))
        let log = try ExerciseLog(
            sessionId: completedSessionID,
            workoutDayExerciseId: workoutDayExerciseID,
            weight: 95,
            reps: 5,
            setNumber: 3
        )

        await #expect(throws: RepositoryError.workoutSessionNotActive) {
            try await repository.saveExerciseLog(log)
        }
    }

    @Test
    func savingTheSameLogicalSetReplacesThePreviousLog() async throws {
        let store = MockSeedData.makeStore()
        let repository = MockWorkoutRepository(store: store)
        let user = try #require(await store.currentUser())
        let activeSession = try #require(await store.activeSession(for: user.id))
        let workoutDayExerciseID = try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888"))
        let originalLogs = try await repository.fetchExerciseLogs(sessionId: activeSession.id)
        let replacementLog = try ExerciseLog(
            sessionId: activeSession.id,
            workoutDayExerciseId: workoutDayExerciseID,
            weight: 67.5,
            reps: 9,
            setNumber: 1
        )

        _ = try await repository.saveExerciseLog(replacementLog)
        let updatedLogs = try await repository.fetchExerciseLogs(sessionId: activeSession.id)
        let matchingLogs = updatedLogs.filter {
            $0.workoutDayExerciseId == workoutDayExerciseID && $0.setNumber == 1
        }

        #expect(updatedLogs.count == originalLogs.count)
        #expect(matchingLogs.count == 1)
        #expect(matchingLogs.first?.weight == 67.5)
        #expect(matchingLogs.first?.reps == 9)
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
