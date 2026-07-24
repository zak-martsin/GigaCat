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
        let fixture = try Fixture(savedSetNumber: 1)
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.loadLogs()

        #expect(viewModel.logsLoadState == .loaded)
        #expect(
            viewModel.savedLogs(
                dayExerciseID: fixture.first.dayExercise.id
            )[1] == fixture.savedLog
        )
    }

    @Test
    func loadLogsFindsLatestLogFromPreviousExerciseSession() async throws {
        let fixture = try Fixture(hasPreviousLog: true)
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.loadLogs()

        #expect(viewModel.logsLoadState == .loaded)
        #expect(
            viewModel.previousLog(
                exerciseID: fixture.first.exercise.id
            ) == fixture.previousLog
        )
    }

    @Test
    func loadLogsRestoresSavedSetsBeyondProgramTarget() async throws {
        let fixture = try Fixture(savedSetNumber: 5)
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.loadLogs()

        #expect(viewModel.setCount(dayExerciseID: fixture.first.dayExercise.id) == 5)
    }

    @Test
    func firstSavedSetStartsSessionAndNotifiesParent() async throws {
        let fixture = try Fixture()
        var changedSession: WorkoutSession?
        var workoutDataChangeCount = 0
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id,
            onSessionChanged: { changedSession = $0 },
            onWorkoutDataChanged: { workoutDataChangeCount += 1 }
        )
        let performedAt = Date(timeIntervalSince1970: 2_000)

        await viewModel.saveSet(
            weight: 62.5,
            reps: 8,
            setNumber: 1,
            performedAt: performedAt
        )

        let savedLog = viewModel.savedLogs(
            dayExerciseID: fixture.first.dayExercise.id
        )[1]
        #expect(viewModel.activeSession?.startedAt == performedAt)
        #expect(savedLog?.weight == 62.5)
        #expect(savedLog?.reps == 8)
        #expect(viewModel.setSaveState == .saved(setNumber: 1, didStartSession: true))
        #expect(changedSession == viewModel.activeSession)
        #expect(workoutDataChangeCount == 1)
    }

    @Test
    func failedSaveDoesNotAddLog() async throws {
        let fixture = try Fixture()
        var workoutDataChangeCount = 0
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id,
            onWorkoutDataChanged: { workoutDataChangeCount += 1 }
        )

        await viewModel.saveSet(weight: 60, reps: 0, setNumber: 1)

        #expect(viewModel.setSaveState == .failed(setNumber: 1))
        #expect(viewModel.logsByDayExerciseID.isEmpty)
        #expect(viewModel.activeSession == nil)
        #expect(workoutDataChangeCount == 0)
    }

    @Test
    func activeSessionFromAnotherDayBlocksSetSave() async throws {
        let fixture = try Fixture()
        let otherDaySession = try WorkoutSession(
            userId: fixture.user.id,
            workoutDayId: UUID()
        )
        let viewModel = WorkoutExerciseViewModel(
            userID: fixture.user.id,
            activeSession: otherDaySession,
            dayContent: fixture.dayContent,
            initialDayExerciseID: fixture.first.dayExercise.id,
            workoutRepository: fixture.repository
        )

        await viewModel.saveSet(weight: 60, reps: 8, setNumber: 1)

        #expect(viewModel.setSaveState == .ready)
        #expect(viewModel.logsByDayExerciseID.isEmpty)
        #expect(viewModel.activeSession == otherDaySession)
    }

    @Test
    func stringInputAcceptsDecimalCommaAndSavesSet() async throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        await viewModel.saveSet(
            weightText: "62,5",
            repsText: "7",
            setNumber: 1
        )

        let savedLog = viewModel.savedLogs(
            dayExerciseID: fixture.first.dayExercise.id
        )[1]
        #expect(savedLog?.weight == 62.5)
        #expect(savedLog?.reps == 7)
        #expect(viewModel.setSaveState == .saved(setNumber: 1, didStartSession: true))
    }

    @Test
    func addsSetsForSelectedExerciseUpToTenWithoutStartingSession() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        for _ in 0..<10 {
            viewModel.addSet()
        }

        #expect(viewModel.setCount(dayExerciseID: fixture.first.dayExercise.id) == 10)
        #expect(viewModel.setCount(dayExerciseID: fixture.second.dayExercise.id) == 3)
        #expect(viewModel.activeSession == nil)
        #expect(viewModel.logsByDayExerciseID.isEmpty)

        viewModel.addSet()

        #expect(viewModel.setCount(dayExerciseID: fixture.first.dayExercise.id) == 10)
    }
}

private extension WorkoutExerciseViewModelTests {
    struct SessionHistory {
        let activeSession: WorkoutSession?
        let savedLog: ExerciseLog?
        let previousSession: WorkoutSession?
        let previousLog: ExerciseLog?
    }

    struct Fixture {
        let user: User
        let first: WorkoutExerciseContent
        let second: WorkoutExerciseContent
        let third: WorkoutExerciseContent
        let dayContent: WorkoutDayContent
        let activeSession: WorkoutSession?
        let savedLog: ExerciseLog?
        let previousLog: ExerciseLog?
        let repository: MockWorkoutRepository

        init(
            savedSetNumber: Int? = nil,
            hasPreviousLog: Bool = false
        ) throws {
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

            let history = try Self.makeSessionHistory(
                userID: user.id,
                dayID: day.id,
                dayExerciseID: first.dayExercise.id,
                savedSetNumber: savedSetNumber,
                hasPreviousLog: hasPreviousLog
            )
            activeSession = history.activeSession
            savedLog = history.savedLog
            previousLog = history.previousLog

            let store = MockDataStore(
                users: [user],
                workoutDays: [day],
                dayExercises: [first, second, third].map(\.dayExercise),
                exercises: [first, second, third].map(\.exercise),
                sessions: [activeSession, history.previousSession].compactMap { $0 },
                exerciseLogs: [savedLog, previousLog].compactMap { $0 },
                currentUserID: user.id
            )
            repository = MockWorkoutRepository(store: store)
        }

        @MainActor
        func makeViewModel(
            initialDayExerciseID: UUID,
            onSessionChanged: @escaping (WorkoutSession) -> Void = { _ in },
            onWorkoutDataChanged: @escaping @MainActor () -> Void = {}
        ) -> WorkoutExerciseViewModel {
            WorkoutExerciseViewModel(
                userID: user.id,
                activeSession: activeSession,
                dayContent: dayContent,
                initialDayExerciseID: initialDayExerciseID,
                workoutRepository: repository,
                onSessionChanged: onSessionChanged,
                onWorkoutDataChanged: onWorkoutDataChanged
            )
        }

        private static func makeSessionHistory(
            userID: UUID,
            dayID: UUID,
            dayExerciseID: UUID,
            savedSetNumber: Int?,
            hasPreviousLog: Bool
        ) throws -> SessionHistory {
            let activeSession = savedSetNumber != nil
                ? try WorkoutSession(userId: userID, workoutDayId: dayID)
                : nil
            let savedLog: ExerciseLog?

            if let activeSession, let savedSetNumber {
                savedLog = try ExerciseLog(
                    sessionId: activeSession.id,
                    workoutDayExerciseId: dayExerciseID,
                    weight: 60,
                    reps: 8,
                    setNumber: savedSetNumber
                )
            } else {
                savedLog = nil
            }

            guard hasPreviousLog else {
                return SessionHistory(
                    activeSession: activeSession,
                    savedLog: savedLog,
                    previousSession: nil,
                    previousLog: nil
                )
            }

            let completedAt = Date(timeIntervalSince1970: 1_000)
            let previousSession = try WorkoutSession(
                userId: userID,
                workoutDayId: dayID,
                status: .completed,
                startedAt: completedAt.addingTimeInterval(-600),
                completedAt: completedAt
            )
            let previousLog = try ExerciseLog(
                sessionId: previousSession.id,
                workoutDayExerciseId: dayExerciseID,
                weight: 57.5,
                reps: 8,
                setNumber: 3,
                performedAt: completedAt
            )
            return SessionHistory(
                activeSession: activeSession,
                savedLog: savedLog,
                previousSession: previousSession,
                previousLog: previousLog
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
                orderIndex: orderIndex
            )

            return WorkoutExerciseContent(
                dayExercise: dayExercise,
                exercise: exercise
            )
        }
    }
}
