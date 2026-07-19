import Foundation
import Testing
@testable import GigaCat

@MainActor
struct HomeViewModelTests {

    @Test
    func tagFilteringUsesTheFullCatalog() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )

        await viewModel.load()
        viewModel.selectTag(.tag(.mobility))

        #expect(viewModel.availableTags.contains(.tag(.mobility)))
        #expect(viewModel.isShowingTagResults)
        #expect(Set(viewModel.tagFilteredPrograms.map(\.title)) == Set(["Conditioning Boost", "Mobility Reset"]))
    }

    @Test
    func searchMatchesTitleDescriptionAndTags() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )

        await viewModel.load()

        viewModel.searchQuery = "strength essentials"
        #expect(viewModel.searchResults.map(\.title) == ["Strength Essentials"])

        viewModel.searchQuery = "posture"
        #expect(viewModel.searchResults.map(\.title) == ["Mobility Reset"])

        viewModel.searchQuery = "hiit"
        #expect(viewModel.searchResults.map(\.title) == ["Conditioning Boost"])

        viewModel.searchQuery = "   "
        #expect(viewModel.searchResults.isEmpty)
    }

    @Test
    func recentExerciseActivityKeepsAnOldSessionAlive() async throws {
        let viewModel = try makeViewModelWithRecentExerciseActivity()

        await viewModel.load()
        let route = await viewModel.handleMiniPlayerAction()

        #expect(route == .openWorkout)
        #expect(viewModel.expiredSessionAlert == nil)
        #expect(viewModel.miniPlayerState.action == .continueWorkout)
    }

    /// Builds a HomeViewModel wired to a scenario where the active session started long ago but has recent log activity.
    private func makeViewModelWithRecentExerciseActivity(
        now: Date = Date()
    ) throws -> HomeViewModel {
        let store = try makeStoreWithRecentExerciseActivity(now: now)
        let factory = MockRepositoryFactory(store: store)
        return HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )
    }

    // swiftlint:disable function_body_length
    /// Creates the minimal seeded store needed to verify that recent exercise logs keep an in-progress session alive.
    private func makeStoreWithRecentExerciseActivity(
        now: Date
    ) throws -> MockDataStore {
        let userID = UUID()
        let programID = UUID()
        let workoutDayID = UUID()
        let exerciseID = UUID()
        let workoutDayExerciseID = UUID()
        let sessionID = UUID()

        return MockDataStore(
            users: [
                try User(
                    id: userID,
                    appleUserId: "active-user",
                    selectedProgramId: programID,
                    createdAt: now.addingTimeInterval(-86_400),
                    updatedAt: now.addingTimeInterval(-86_400)
                )
            ],
            programs: [
                try WorkoutProgram(
                    id: programID,
                    title: "Searchable Strength",
                    description: "A simple strength plan.",
                    tags: [.strength]
                )
            ],
            programCatalogMetadataByProgramID: [
                programID: ProgramCatalogMetadata(
                    isRecommended: true,
                    isPopular: true,
                    rateScore: 4.7
                )
            ],
            workoutDays: [
                try WorkoutDay(
                    id: workoutDayID,
                    programId: programID,
                    title: "Heavy Day",
                    orderIndex: 0
                )
            ],
            dayExercises: [
                try WorkoutDayExercise(
                    id: workoutDayExerciseID,
                    workoutDayId: workoutDayID,
                    exerciseId: exerciseID,
                    targetSets: 3,
                    targetReps: 5,
                    targetWeight: 100,
                    orderIndex: 0
                )
            ],
            exercises: [
                try Exercise(
                    id: exerciseID,
                    name: "Back Squat",
                    muscleGroup: .legs
                )
            ],
            sessions: [
                try WorkoutSession(
                    id: sessionID,
                    userId: userID,
                    workoutDayId: workoutDayID,
                    startedAt: now.addingTimeInterval(-(60 * 60 * 9))
                )
            ],
            exerciseLogs: [
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: workoutDayExerciseID,
                    weight: 100,
                    reps: 5,
                    setNumber: 1,
                    performedAt: now.addingTimeInterval(-900)
                )
            ],
            currentUserID: userID
        )
    }
    // swiftlint:enable function_body_length
}
