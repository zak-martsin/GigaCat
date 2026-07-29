import Foundation
import Testing
@testable import GigaCat

@MainActor
struct MiniPlayerViewModelTests {
    @Test
    func recentExerciseActivityKeepsAnOldSessionAlive() async throws {
        let factory = MockRepositoryFactory(store: try makeStore(now: Date()))
        let viewModel = makeViewModel(factory: factory)

        await viewModel.reload()
        let route = viewModel.handlePrimaryAction()

        #expect(route == .openWorkout)
        #expect(viewModel.expiredSessionAlert == nil)
        #expect(viewModel.state.action == .continueWorkout)
        #expect(viewModel.programID != nil)
    }

    @Test
    func reloadReflectsACompletedSessionImmediately() async throws {
        let factory = MockRepositoryFactory(store: try makeStore(now: Date()))
        let viewModel = makeViewModel(factory: factory)

        await viewModel.reload()
        #expect(viewModel.state.action == .continueWorkout)

        let user = try #require(try await factory.userRepository.currentUser())
        let session = try #require(try await factory.workoutRepository.activeSession(for: user.id))
        _ = try await factory.workoutRepository.completeSession(
            sessionId: session.id,
            completedAt: Date()
        )

        await viewModel.reload()

        #expect(viewModel.state.action == .start)
    }

    private func makeViewModel(factory: MockRepositoryFactory) -> MiniPlayerViewModel {
        MiniPlayerViewModel(
            service: MiniPlayerService(
                userRepository: factory.userRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            ),
            workoutRepository: factory.workoutRepository
        )
    }

    // swiftlint:disable function_body_length
    /// Creates an old session whose recent exercise log keeps it active.
    private func makeStore(now: Date) throws -> MockDataStore {
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
