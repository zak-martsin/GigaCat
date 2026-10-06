import Foundation
import Testing
@testable import GigaCat

@MainActor
struct WorkoutViewModelTests {

    @Test
    func initialStateIsLoadingWithoutWorkoutData() {
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: []),
            workoutRepository: makeWorkoutRepository()
        )

        #expect(viewModel.loadState == .loading)
        #expect(viewModel.context == nil)
        #expect(viewModel.selectedDayID == nil)
    }

    @Test
    func loadStoresContextAndSelectsItsInitialDay() async throws {
        let context = try makeContext()
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.context == context)
        #expect(viewModel.program == context.program)
        #expect(viewModel.days == context.dayContents.map(\.day))
        #expect(viewModel.selectedDayID == context.initialDayID)
        #expect(viewModel.selectedDay?.id == context.initialDayID)
        #expect(viewModel.selectedDayContent == context.dayContents[0])
        #expect(viewModel.activeSession == context.activeSession)
    }

    @Test
    func missingSelectedProgramProducesEmptyState() async {
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(nil)]),
            workoutRepository: makeWorkoutRepository()
        )

        await viewModel.load()

        #expect(viewModel.loadState == .empty)
        #expect(viewModel.context == nil)
        #expect(viewModel.selectedDayID == nil)
    }

    @Test
    func selectDayChangesOnlyTheInspectedDay() async throws {
        let context = try makeContext(hasActiveSession: true)
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository()
        )
        await viewModel.load()

        let secondDay = context.dayContents[1].day
        viewModel.selectDay(id: secondDay.id)

        #expect(viewModel.selectedDayID == secondDay.id)
        #expect(viewModel.selectedDayContent == context.dayContents[1])
        #expect(viewModel.activeSession?.workoutDayId == context.initialDayID)
        #expect(!viewModel.hasActiveSessionForSelectedDay)
    }

    @Test
    func selectDayIgnoresDayOutsideCurrentContext() async throws {
        let context = try makeContext()
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository()
        )
        await viewModel.load()

        viewModel.selectDay(id: UUID())

        #expect(viewModel.selectedDayID == context.initialDayID)
    }

    @Test
    func failedReloadClearsPreviouslyLoadedContext() async throws {
        let context = try makeContext()
        let service = WorkoutContextServiceStub(
            results: [
                .success(context),
                .failure(.loadFailed)
            ]
        )
        let viewModel = WorkoutViewModel(
            contextService: service,
            workoutRepository: makeWorkoutRepository()
        )

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.loadState == .failed)
        #expect(viewModel.context == nil)
        #expect(viewModel.selectedDayID == nil)
    }

    @Test
    func finishActiveSessionCompletesItAndLoadsNextContext() async throws {
        let activeContext = try makeContext(hasActiveSession: true)
        let nextDayID = activeContext.dayContents[1].day.id
        let nextContext = context(
            replacing: activeContext,
            initialDayID: nextDayID
        )
        let activeSession = try #require(activeContext.activeSession)
        let repository = makeWorkoutRepository(sessions: [activeSession])
        var invalidationCount = 0
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(
                results: [.success(activeContext), .success(nextContext)]
            ),
            workoutRepository: repository,
            onDataChanged: { change in
                #expect(change == .workoutSession)
                invalidationCount += 1
            }
        )
        let completedAt = activeSession.startedAt.addingTimeInterval(600)

        await viewModel.load()
        #expect(viewModel.hasActiveSessionForSelectedDay)

        let dayContent = try #require(viewModel.selectedDayContent)
        let dayExerciseID = try #require(dayContent.exercises.first?.dayExercise.id)
        let exerciseViewModel = try #require(
            viewModel.makeExerciseViewModel(
                dayContent: dayContent,
                initialDayExerciseID: dayExerciseID
            )
        )
        exerciseViewModel.addSet()
        #expect(viewModel.exerciseSetCounts[dayExerciseID] == 4)

        await viewModel.finishActiveSession(completedAt: completedAt)

        let sessions = try await repository.fetchSessions(for: activeContext.userID)
        #expect(sessions.first?.status == .completed)
        #expect(sessions.first?.completedAt == completedAt)
        #expect(viewModel.context == nextContext)
        #expect(viewModel.selectedDayID == nextDayID)
        #expect(viewModel.sessionActionState == .idle)
        #expect(viewModel.exerciseSetCounts.isEmpty)
        #expect(invalidationCount == 1)
    }

    @Test
    func cancelActiveSessionDeletesItAndLoadsReadyContext() async throws {
        let activeContext = try makeContext(hasActiveSession: true)
        let readyContext = context(
            replacing: activeContext,
            initialDayID: activeContext.initialDayID
        )
        let activeSession = try #require(activeContext.activeSession)
        let repository = makeWorkoutRepository(sessions: [activeSession])
        var invalidationCount = 0
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(
                results: [.success(activeContext), .success(readyContext)]
            ),
            workoutRepository: repository,
            onDataChanged: { change in
                #expect(change == .workoutSession)
                invalidationCount += 1
            }
        )

        await viewModel.load()
        await viewModel.cancelActiveSession()

        let sessions = try await repository.fetchSessions(for: activeContext.userID)
        #expect(sessions.isEmpty)
        #expect(viewModel.context == readyContext)
        #expect(viewModel.activeSession == nil)
        #expect(viewModel.sessionActionState == .idle)
        #expect(invalidationCount == 1)
    }

    @Test
    func savedSetUpdatesSessionAndUpsertsLogInContext() async throws {
        let context = try makeContext()
        let repository = makeWorkoutRepository(for: context)
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: repository
        )
        await viewModel.load()

        let dayContent = try #require(viewModel.selectedDayContent)
        let dayExerciseID = try #require(dayContent.exercises.first?.dayExercise.id)
        let exerciseViewModel = try #require(
            viewModel.makeExerciseViewModel(
                dayContent: dayContent,
                initialDayExerciseID: dayExerciseID
            )
        )

        await exerciseViewModel.saveSet(weight: 60, reps: 8, setNumber: 1)
        let firstLog = try #require(viewModel.context?.activeSessionLogs.first)

        await exerciseViewModel.saveSet(weight: 65, reps: 6, setNumber: 1)

        #expect(viewModel.activeSession == exerciseViewModel.activeSession)
        #expect(viewModel.context?.activeSessionLogs.count == 1)
        #expect(viewModel.context?.activeSessionLogs.first?.id == firstLog.id)
        #expect(viewModel.context?.activeSessionLogs.first?.weight == 65)
        #expect(viewModel.context?.activeSessionLogs.first?.reps == 6)
    }

    @Test
    func addedSetUpdatesParentCountAndReopenedExercise() async throws {
        let context = try makeContext(hasActiveSession: true)
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository()
        )
        await viewModel.load()

        let dayContent = try #require(viewModel.selectedDayContent)
        let dayExerciseID = try #require(dayContent.exercises.first?.dayExercise.id)
        let exerciseViewModel = try #require(
            viewModel.makeExerciseViewModel(
                dayContent: dayContent,
                initialDayExerciseID: dayExerciseID
            )
        )

        exerciseViewModel.addSet()

        #expect(viewModel.exerciseSetCounts[dayExerciseID] == 4)

        let reopenedViewModel = try #require(
            viewModel.makeExerciseViewModel(
                dayContent: dayContent,
                initialDayExerciseID: dayExerciseID
            )
        )
        #expect(reopenedViewModel.setCount(dayExerciseID: dayExerciseID) == 4)
    }

    @Test
    func artworkLoadsOnlyAfterVisibleRowRequestsIt() async throws {
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 1)
        let context = try makeContext(artwork: artwork)
        let service = ArtworkServiceTestDouble(
            fileURL: URL(filePath: "/tmp/bench-press.png")
        )
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository(),
            artworkService: service
        )
        let exerciseID = try #require(
            context.dayContents.first?.exercises.first?.exercise.id
        )

        await viewModel.load()
        #expect(await service.requests.isEmpty)

        await viewModel.loadArtwork(for: exerciseID)

        #expect(viewModel.exerciseArtworkFileURLs[exerciseID]?.lastPathComponent == "bench-press.png")
        #expect(
            await service.requests == [
                .init(owner: .exercise(exerciseID), artwork: artwork)
            ]
        )
    }

    @Test
    func artworkFailureKeepsPlaceholderState() async throws {
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 1)
        let context = try makeContext(artwork: artwork)
        let service = ArtworkServiceTestDouble(error: .unavailable)
        let viewModel = WorkoutViewModel(
            contextService: WorkoutContextServiceStub(results: [.success(context)]),
            workoutRepository: makeWorkoutRepository(),
            artworkService: service
        )
        let exerciseID = try #require(
            context.dayContents.first?.exercises.first?.exercise.id
        )

        await viewModel.load()
        await viewModel.loadArtwork(for: exerciseID)

        #expect(viewModel.exerciseArtworkFileURLs[exerciseID] == nil)
    }
}

private extension WorkoutViewModelTests {
    func makeContext(
        hasActiveSession: Bool = false,
        artwork: ArtworkReference? = nil
    ) throws -> WorkoutContext {
        let programID = UUID()
        let firstDayID = UUID()
        let userID = UUID()
        let program = try WorkoutProgram(
            id: programID,
            title: "Strength Program",
            description: "A program used to test Workout state."
        )
        let days = [
            try WorkoutDay(
                id: firstDayID,
                programId: programID,
                title: "Push",
                orderIndex: 0
            ),
            try WorkoutDay(
                programId: programID,
                title: "Pull",
                orderIndex: 1
            )
        ]
        let exercise = try Exercise(
            name: "Bench Press",
            muscleGroup: .chest,
            artwork: artwork
        )
        let dayExercise = try WorkoutDayExercise(
            workoutDayId: firstDayID,
            exerciseId: exercise.id,
            targetSets: 3,
            targetReps: 8,
            orderIndex: 0
        )
        let dayContents = [
            WorkoutDayContent(
                day: days[0],
                exercises: [
                    WorkoutExerciseContent(
                        dayExercise: dayExercise,
                        exercise: exercise
                    )
                ]
            ),
            WorkoutDayContent(day: days[1], exercises: [])
        ]
        let activeSession = try makeActiveSession(
            userID: userID,
            dayID: firstDayID,
            isActive: hasActiveSession
        )

        return WorkoutContext(
            userID: userID,
            program: program,
            dayContents: dayContents,
            initialDayID: firstDayID,
            activeSession: activeSession,
            activeSessionLogs: []
        )
    }

    func makeActiveSession(
        userID: UUID,
        dayID: UUID,
        isActive: Bool
    ) throws -> WorkoutSession? {
        guard isActive else { return nil }
        return try WorkoutSession(userId: userID, workoutDayId: dayID)
    }

    func context(
        replacing context: WorkoutContext,
        initialDayID: UUID
    ) -> WorkoutContext {
        WorkoutContext(
            userID: context.userID,
            program: context.program,
            dayContents: context.dayContents,
            initialDayID: initialDayID,
            activeSession: nil,
            activeSessionLogs: []
        )
    }

    func makeWorkoutRepository(
        sessions: [WorkoutSession] = []
    ) -> MockWorkoutRepository {
        MockWorkoutRepository(
            store: MockDataStore(sessions: sessions)
        )
    }

    func makeWorkoutRepository(for context: WorkoutContext) -> MockWorkoutRepository {
        let exercises = context.dayContents.flatMap(\.exercises)
        let store = MockDataStore(
            users: [User(id: context.userID, selectedProgramId: context.program.id)],
            programs: [context.program],
            workoutDays: context.dayContents.map(\.day),
            dayExercises: exercises.map(\.dayExercise),
            exercises: exercises.map(\.exercise),
            sessions: [context.activeSession].compactMap { $0 },
            exerciseLogs: context.activeSessionLogs,
            currentUserID: context.userID
        )
        return MockWorkoutRepository(store: store)
    }
}

private actor WorkoutContextServiceStub: WorkoutContextServicing {
    enum StubError: Error {
        case loadFailed
        case missingResult
    }

    private var results: [Result<WorkoutContext?, StubError>]

    init(results: [Result<WorkoutContext?, StubError>]) {
        self.results = results
    }

    func loadContext() async throws -> WorkoutContext? {
        guard !results.isEmpty else { throw StubError.missingResult }
        return try results.removeFirst().get()
    }
}
