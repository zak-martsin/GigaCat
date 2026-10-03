import Foundation
import Observation

enum WorkoutLoadState: Equatable {
    case loading
    case empty
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
    private(set) var exerciseArtworkFileURLs: [UUID: URL] = [:]

    @ObservationIgnored
    private let contextService: WorkoutContextServicing

    @ObservationIgnored
    private let workoutRepository: WorkoutRepository

    @ObservationIgnored
    private let artworkService: any ArtworkServicing

    @ObservationIgnored
    private let onDataChanged: AppDataChangeHandler

    @ObservationIgnored
    private var loadTracker = DataLoadTracker()

    @ObservationIgnored
    private var isLoading = false

    @ObservationIgnored
    private var loadedArtworkReferences: [UUID: ArtworkReference] = [:]

    init(
        contextService: WorkoutContextServicing,
        workoutRepository: WorkoutRepository,
        artworkService: any ArtworkServicing,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.contextService = contextService
        self.workoutRepository = workoutRepository
        self.artworkService = artworkService
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

        isLoading = true
        defer { isLoading = false }

        repeat {
            let loadingRevision = loadTracker.currentRevision
            loadState = .loading

            do {
                guard let context = try await contextService.loadContext() else {
                    self.context = nil
                    selectedDayID = nil
                    exerciseArtworkFileURLs = [:]
                    loadedArtworkReferences = [:]
                    loadTracker.markLoaded(revision: loadingRevision)
                    loadState = .empty
                    continue
                }

                self.context = context
                preserveCurrentArtworkURLs(in: context)
                selectedDayID = context.initialDayID
                loadTracker.markLoaded(revision: loadingRevision)
                loadState = .loaded
            } catch {
                context = nil
                selectedDayID = nil
                exerciseArtworkFileURLs = [:]
                loadedArtworkReferences = [:]
                loadState = .failed
                return
            }
        } while loadTracker.needsLoading
    }

    /// Changes the inspected day without changing the day of an active session.
    func selectDay(id: UUID) {
        guard days.contains(where: { $0.id == id }) else { return }
        selectedDayID = id
    }

    // MARK: - Exercise Artwork

    /// Resolves artwork only when a visible exercise row asks for it.
    func loadArtwork(for exerciseID: UUID) async {
        guard let artwork = exercise(withID: exerciseID)?.artwork,
              loadedArtworkReferences[exerciseID] != artwork
                || exerciseArtworkFileURLs[exerciseID] == nil else {
            return
        }

        do {
            let fileURL = try await artworkService.fileURL(
                for: .exercise(exerciseID),
                artwork: artwork
            )
            guard !Task.isCancelled,
                  exercise(withID: exerciseID)?.artwork == artwork else {
                return
            }

            loadedArtworkReferences[exerciseID] = artwork
            exerciseArtworkFileURLs[exerciseID] = fileURL
        } catch {
            // Artwork is optional presentation; the row keeps its placeholder on failure.
        }
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
                userId: activeSession.userId,
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
            try await workoutRepository.deleteSession(
                sessionId: activeSession.id,
                userId: activeSession.userId
            )
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
            artworkService: artworkService,
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

    private func exercise(withID exerciseID: UUID) -> Exercise? {
        context?.dayContents
            .lazy
            .flatMap(\.exercises)
            .first { $0.exercise.id == exerciseID }?
            .exercise
    }

    private func preserveCurrentArtworkURLs(in context: WorkoutContext) {
        let currentReferences = Dictionary(
            context.dayContents
                .flatMap(\.exercises)
                .compactMap { content in
                    content.exercise.artwork.map { (content.exercise.id, $0) }
                },
            uniquingKeysWith: { current, _ in current }
        )

        exerciseArtworkFileURLs = exerciseArtworkFileURLs.filter {
            loadedArtworkReferences[$0.key] == currentReferences[$0.key]
        }
        loadedArtworkReferences = loadedArtworkReferences.filter {
            currentReferences[$0.key] == $0.value
        }
    }
}
