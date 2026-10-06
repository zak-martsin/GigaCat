import Testing
@testable import GigaCat

@MainActor
extension WorkoutExerciseViewModelTests {
    @Test
    func loadLogsLoadsCompletedExerciseHistory() async throws {
        let fixture = try Fixture(hasPreviousLog: true)
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.loadLogs()

        let history = viewModel.historySummary(
            exerciseID: fixture.first.exercise.id
        )
        #expect(history?.previousLog == fixture.previousLog)
        #expect(history?.bestLog == fixture.previousLog)
        #expect(viewModel.logsLoadState == .loaded)
    }

    @Test
    func savingCurrentSetDoesNotChangeCompletedExerciseHistory() async throws {
        let fixture = try Fixture(
            savedSetNumber: 1,
            hasPreviousLog: true
        )
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )
        await viewModel.loadLogs()
        let originalHistory = viewModel.historySummary(
            exerciseID: fixture.first.exercise.id
        )

        await viewModel.saveSet(weight: 100, reps: 2, setNumber: 1)

        #expect(
            viewModel.latestLog(exerciseID: fixture.first.exercise.id)?.weight == 100
        )
        #expect(
            viewModel.historySummary(exerciseID: fixture.first.exercise.id) == originalHistory
        )
    }

    @Test
    func historyFailureKeepsLoggingAndLatestSuggestionAvailable() async throws {
        let fixture = try Fixture(hasPreviousLog: true)
        let repository = WorkoutRepositoryTestDouble(
            base: fixture.repository,
            failure: .exerciseHistorySummary
        )
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id,
            workoutRepository: repository
        )

        await viewModel.loadLogs()

        #expect(viewModel.logsLoadState == .partiallyLoaded)
        #expect(viewModel.historyByExerciseID.isEmpty)
        #expect(
            viewModel.latestLog(exerciseID: fixture.first.exercise.id) == fixture.previousLog
        )
    }
}
