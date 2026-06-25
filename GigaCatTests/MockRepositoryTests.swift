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
        let program = try #require(await store.programs().first)

        let days = try await repository.fetchWorkoutDays(programId: program.id)

        #expect(days.map(\.title) == ["Push", "Pull"])
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
}
