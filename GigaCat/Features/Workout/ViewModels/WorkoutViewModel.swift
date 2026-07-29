import Foundation
import Observation

enum WorkoutLoadState: Equatable {
    case loading
    case loaded
    case failed
}

enum WorkoutSessionActionState: Equatable {
    case idle
    case finishing
    case cancelling
}

@MainActor
@Observable
final class WorkoutViewModel {
    private(set) var context: WorkoutContext?
    private(set) var loadState: WorkoutLoadState = .loading
    private(set) var selectedDayID: UUID?
    private(set) var sessionActionState: WorkoutSessionActionState = .idle

    @ObservationIgnored
    private let contextService: WorkoutContextServicing

    @ObservationIgnored
    private let workoutRepository: WorkoutRepository

    @ObservationIgnored
    private let onDataChanged: AppDataChangeHandler

    @ObservationIgnored
    private var loadTracker = DataLoadTracker()

    @ObservationIgnored
    private var isLoading = false

    init(
        contextService: WorkoutContextServicing,
        workoutRepository: WorkoutRepository,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.contextService = contextService
        self.workoutRepository = workoutRepository
        self.onDataChanged = onDataChanged
    }

    // MARK: - Presentation State

    var program: WorkoutProgram? {
        context?.program
    }

    var days: [WorkoutDay] {
        context?.dayContents.map(\.day) ?? []
    }

    var selectedDayContent: WorkoutDayContent? {
        guard let selectedDayID else { return nil }
        return context?.dayContents.first { $0.day.id == selectedDayID }
    }

    var selectedDay: WorkoutDay? {
        selectedDayContent?.day
    }

    var activeSession: WorkoutSession? {
        context?.activeSession
    }

    var hasActiveSessionForSelectedDay: Bool {
        guard let activeSession, let selectedDayID else { return false }
        return activeSession.workoutDayId == selectedDayID
    }

    var isSessionActionInProgress: Bool {
        sessionActionState != .idle
    }

    // MARK: - Context Loading and Day Selection

    func loadIfNeeded() async {
        guard loadTracker.needsLoading else { return }
        await load()
    }

    func invalidate() {
        loadTracker.invalidate()
    }

    /// Reloads the workout entry context from the repository-backed context service.
    func load() async {
        guard !isLoading else { return }

        let loadingRevision = loadTracker.currentRevision
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        do {
            let context = try await contextService.loadContext()
            self.context = context
            selectedDayID = context.initialDayID
            loadTracker.markLoaded(revision: loadingRevision)
            loadState = .loaded
        } catch {
            context = nil
            selectedDayID = nil
            loadState = .failed
        }
    }

    /// Changes the inspected day without changing the day of an active session.
    func selectDay(id: UUID) {
        guard days.contains(where: { $0.id == id }) else { return }
        selectedDayID = id
    }

    // MARK: - Session Actions

    func finishActiveSession(completedAt: Date = Date()) async {
        guard let activeSession,
              activeSession.workoutDayId == selectedDayID,
              !isSessionActionInProgress else {
            return
        }

        sessionActionState = .finishing

        do {
            _ = try await workoutRepository.completeSession(
                sessionId: activeSession.id,
                completedAt: completedAt
            )
            await onDataChanged(.workoutSession)
            sessionActionState = .idle
            await load()
        } catch {
            sessionActionState = .idle
        }
    }

    func cancelActiveSession() async {
        guard let activeSession,
              activeSession.workoutDayId == selectedDayID,
              !isSessionActionInProgress else {
            return
        }

        sessionActionState = .cancelling

        do {
            try await workoutRepository.deleteSession(sessionId: activeSession.id)
            await onDataChanged(.workoutSession)
            sessionActionState = .idle
            await load()
        } catch {
            sessionActionState = .idle
        }
    }

    // MARK: - Exercise Detail

    func makeExerciseViewModel(
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID
    ) -> WorkoutExerciseViewModel? {
        guard let context,
              context.dayContents.contains(where: { $0.day.id == dayContent.day.id }) else {
            return nil
        }

        return WorkoutExerciseViewModel(
            userID: context.userID,
            activeSession: context.activeSession,
            dayContent: dayContent,
            initialDayExerciseID: initialDayExerciseID,
            workoutRepository: workoutRepository,
            onSessionChanged: updateActiveSession,
            onDataChanged: onDataChanged
        )
    }

    private func updateActiveSession(_ session: WorkoutSession) {
        guard let context else { return }

        self.context = WorkoutContext(
            userID: context.userID,
            program: context.program,
            dayContents: context.dayContents,
            initialDayID: context.initialDayID,
            activeSession: session
        )
    }
}
