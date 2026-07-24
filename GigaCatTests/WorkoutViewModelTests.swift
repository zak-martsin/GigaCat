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
            onWorkoutDataChanged: {
                invalidationCount += 1
            }
        )
        let completedAt = activeSession.startedAt.addingTimeInterval(600)

        await viewModel.load()
        #expect(viewModel.hasActiveSessionForSelectedDay)

        await viewModel.finishActiveSession(completedAt: completedAt)

        let sessions = try await repository.fetchSessions(for: activeContext.userID)
        #expect(sessions.first?.status == .completed)
        #expect(sessions.first?.completedAt == completedAt)
        #expect(viewModel.context == nextContext)
        #expect(viewModel.selectedDayID == nextDayID)
        #expect(viewModel.sessionActionState == .idle)
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
            onWorkoutDataChanged: {
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
}

private extension WorkoutViewModelTests {
    func makeContext(hasActiveSession: Bool = false) throws -> WorkoutContext {
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
            muscleGroup: .chest
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
        let activeSession: WorkoutSession? = if hasActiveSession {
            try WorkoutSession(
                userId: userID,
                workoutDayId: firstDayID
            )
        } else {
            nil
        }

        return WorkoutContext(
            userID: userID,
            program: program,
            dayContents: dayContents,
            initialDayID: firstDayID,
            activeSession: activeSession
        )
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
            activeSession: nil
        )
    }

    func makeWorkoutRepository(
        sessions: [WorkoutSession] = []
    ) -> MockWorkoutRepository {
        MockWorkoutRepository(
            store: MockDataStore(sessions: sessions)
        )
    }
}

private actor WorkoutContextServiceStub: WorkoutContextServicing {
    enum StubError: Error {
        case loadFailed
        case missingResult
    }

    private var results: [Result<WorkoutContext, StubError>]

    init(results: [Result<WorkoutContext, StubError>]) {
        self.results = results
    }

    func loadContext() async throws -> WorkoutContext {
        guard !results.isEmpty else { throw StubError.missingResult }
        return try results.removeFirst().get()
    }
}
