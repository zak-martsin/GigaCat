import Combine
import Foundation

/// App-scoped state and actions for the workout mini player.
@MainActor
final class MiniPlayerViewModel: ObservableObject {
    @Published private(set) var state: MiniPlayerState = .empty
    @Published var expiredSessionAlert: ExpiredSessionAlert?
    @Published private(set) var errorMessage: String?

    private let service: MiniPlayerServicing
    private let workoutRepository: WorkoutRepository
    private let alertBuilder: MiniPlayerAlertBuilding
    private let onDataChanged: AppDataChangeHandler
    private var context: MiniPlayerContext = .noProgramSelected
    private var isLoading = false

    init(
        service: MiniPlayerServicing,
        workoutRepository: WorkoutRepository,
        alertBuilder: MiniPlayerAlertBuilding = MiniPlayerAlertBuilder(),
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.service = service
        self.workoutRepository = workoutRepository
        self.alertBuilder = alertBuilder
        self.onDataChanged = onDataChanged
    }

    /// Immediately refreshes the player because it is visible independently of the selected tab.
    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let presentation = try await service.makePresentation()
            state = presentation.state
            context = presentation.context
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handlePrimaryAction() -> MiniPlayerRoute {
        switch context {
        case .noProgramSelected:
            return .none
        case .readyToStart:
            return .openWorkout
        case let .activeSession(session, programTitle, workoutDayTitle, isExpired):
            guard isExpired else { return .openWorkout }
            expiredSessionAlert = alertBuilder.makeExpiredSessionAlert(
                sessionID: session.id,
                programTitle: programTitle,
                workoutDayTitle: workoutDayTitle
            )
            return .none
        }
    }

    func continueExpiredSession() -> MiniPlayerRoute {
        expiredSessionAlert = nil
        return .openWorkout
    }

    func completeExpiredSession() async {
        guard case let .activeSession(session, _, _, _) = context else { return }

        do {
            _ = try await workoutRepository.completeSession(
                sessionId: session.id,
                completedAt: Date()
            )
            expiredSessionAlert = nil
            await onDataChanged(.workoutSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteExpiredSession() async {
        guard case let .activeSession(session, _, _, _) = context else { return }

        do {
            try await workoutRepository.deleteSession(sessionId: session.id)
            expiredSessionAlert = nil
            await onDataChanged(.workoutSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
