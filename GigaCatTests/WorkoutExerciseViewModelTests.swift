import Foundation
import Testing
@testable import GigaCat

@MainActor
struct WorkoutExerciseViewModelTests {

    @Test
    func selectsRequestedExerciseAfterOrderingDayContent() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.second.dayExercise.id
        )

        #expect(viewModel.day == fixture.dayContent.day)
        #expect(viewModel.exercises.map(\.dayExercise.orderIndex) == [0, 1, 2])
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)
        #expect(viewModel.selectedExercise == fixture.second)
        #expect(viewModel.selectedExerciseIndex == 1)
        #expect(viewModel.canSelectPreviousExercise)
        #expect(viewModel.canSelectNextExercise)
    }

    @Test
    func selectsPreviousAndNextExercisesWithinDayBounds() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        viewModel.selectPreviousExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.first.dayExercise.id)
        #expect(!viewModel.canSelectPreviousExercise)

        viewModel.selectNextExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)

        viewModel.selectNextExercise()
        viewModel.selectNextExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.third.dayExercise.id)
        #expect(!viewModel.canSelectNextExercise)

        viewModel.selectPreviousExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)
    }

    @Test
    func fallsBackToFirstExerciseWhenInitialIDIsOutsideDay() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(initialDayExerciseID: UUID())

        #expect(viewModel.selectedDayExerciseID == fixture.first.dayExercise.id)
        #expect(viewModel.selectedExerciseIndex == 0)
    }

    @Test
    func emptyDayHasNoExerciseSelection() throws {
        let fixture = try Fixture()
        let viewModel = WorkoutExerciseViewModel(
            userID: fixture.user.id,
            activeSession: nil,
            dayContent: WorkoutDayContent(day: fixture.dayContent.day, exercises: []),
            initialDayExerciseID: UUID(),
            workoutRepository: fixture.repository
        )

        #expect(viewModel.selectedDayExerciseID == nil)
        #expect(viewModel.selectedExercise == nil)
        #expect(viewModel.selectedExerciseIndex == nil)
        #expect(!viewModel.canSelectPreviousExercise)
        #expect(!viewModel.canSelectNextExercise)
    }

    @Test
    func loadLogsIndexesSavedSetsByExerciseAndSetNumber() async throws {
        let fixture = try Fixture(hasSavedLog: true)
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.loadLogs()

        #expect(viewModel.logsLoadState == .loaded)
        #expect(
            viewModel.savedLog(
                dayExerciseID: fixture.first.dayExercise.id,
                setNumber: 1
            ) == fixture.savedLog
        )
    }

    @Test
    func firstSavedSetStartsSessionAndNotifiesParent() async throws {
        let fixture = try Fixture()
        var changedSession: WorkoutSession?
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id,
            onSessionChanged: { changedSession = $0 }
        )
        let performedAt = Date(timeIntervalSince1970: 2_000)

        await viewModel.saveSet(
            weight: 62.5,
            reps: 8,
            setNumber: 1,
            performedAt: performedAt
        )

        let savedLog = viewModel.savedLog(
            dayExerciseID: fixture.first.dayExercise.id,
            setNumber: 1
        )
        #expect(viewModel.activeSession?.startedAt == performedAt)
        #expect(savedLog?.weight == 62.5)
        #expect(savedLog?.reps == 8)
        #expect(viewModel.setSaveState == .saved(setNumber: 1, didStartSession: true))
        #expect(changedSession == viewModel.activeSession)
    }

    @Test
    func failedSaveDoesNotAddLog() async throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.saveSet(weight: 60, reps: 0, setNumber: 1)

        #expect(viewModel.setSaveState == .failed(setNumber: 1))
        #expect(viewModel.logsByDayExerciseID.isEmpty)
        #expect(viewModel.activeSession == nil)
    }
}

private extension WorkoutExerciseViewModelTests {
    struct Fixture {
        let user: User
        let first: WorkoutExerciseContent
        let second: WorkoutExerciseContent
        let third: WorkoutExerciseContent
        let dayContent: WorkoutDayContent
        let activeSession: WorkoutSession?
        let savedLog: ExerciseLog?
        let repository: MockWorkoutRepository

        init(hasSavedLog: Bool = false) throws {
            user = try User(appleUserId: "workout-exercise-view-model-user")
            let programID = UUID()
            let day = try WorkoutDay(
                programId: programID,
                title: "Strength Day",
                orderIndex: 0
            )
            let first = try Self.makeExerciseContent(
                name: "Bench Press",
                dayID: day.id,
                orderIndex: 0
            )
            let second = try Self.makeExerciseContent(
                name: "Incline Press",
                dayID: day.id,
                orderIndex: 1
            )
            let third = try Self.makeExerciseContent(
                name: "Chest Fly",
                dayID: day.id,
                orderIndex: 2
            )

            self.first = first
            self.second = second
            self.third = third
            dayContent = WorkoutDayContent(
                day: day,
                exercises: [third, first, second]
            )

            if hasSavedLog {
                let session = try WorkoutSession(
                    userId: user.id,
                    workoutDayId: day.id
                )
                let log = try ExerciseLog(
                    sessionId: session.id,
                    workoutDayExerciseId: first.dayExercise.id,
                    weight: 60,
                    reps: 8,
                    setNumber: 1
                )
                activeSession = session
                savedLog = log
            } else {
                activeSession = nil
                savedLog = nil
            }

            let store = MockDataStore(
                users: [user],
                workoutDays: [day],
                dayExercises: [first, second, third].map(\.dayExercise),
                exercises: [first, second, third].map(\.exercise),
                sessions: activeSession.map { [$0] } ?? [],
                exerciseLogs: savedLog.map { [$0] } ?? [],
                currentUserID: user.id
            )
            repository = MockWorkoutRepository(store: store)
        }

        @MainActor
        func makeViewModel(
            initialDayExerciseID: UUID,
            onSessionChanged: @escaping (WorkoutSession) -> Void = { _ in }
        ) -> WorkoutExerciseViewModel {
            WorkoutExerciseViewModel(
                userID: user.id,
                activeSession: activeSession,
                dayContent: dayContent,
                initialDayExerciseID: initialDayExerciseID,
                workoutRepository: repository,
                onSessionChanged: onSessionChanged
            )
        }

        private static func makeExerciseContent(
            name: String,
            dayID: UUID,
            orderIndex: Int
        ) throws -> WorkoutExerciseContent {
            let exercise = try Exercise(name: name, muscleGroup: .chest)
            let dayExercise = try WorkoutDayExercise(
                workoutDayId: dayID,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                targetWeight: 60,
                orderIndex: orderIndex
            )

            return WorkoutExerciseContent(
                dayExercise: dayExercise,
                exercise: exercise
            )
        }
    }
}
