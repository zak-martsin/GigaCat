import Combine
import Foundation

/// Reusable state and intents for presenting a program detail outside a feature-owned screen.
@MainActor
final class ProgramDetailViewModel: ObservableObject {
    @Published var presentedDetail: ProgramDetail?
    @Published var selectionConflictAlert: ProgramSelectionConflictAlert?
    @Published var errorMessage: String?

    private let userRepository: UserRepository
    private let service: ProgramDetailServicing
    private let onDataChanged: AppDataChangeHandler
    private var currentUser: User?
    private var pendingProgramID: UUID?

    init(
        userRepository: UserRepository,
        service: ProgramDetailServicing,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.userRepository = userRepository
        self.service = service
        self.onDataChanged = onDataChanged
    }

    func present(programID: UUID) async {
        errorMessage = nil

        do {
            guard let user = try await userRepository.currentUser() else {
                errorMessage = "No active user was found."
                return
            }

            currentUser = user
            presentedDetail = try await service.makeDetail(for: programID, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismiss() {
        presentedDetail = nil
    }

    func selectPresentedProgram() async {
        guard let detail = presentedDetail,
              let currentUser else {
            return
        }

        do {
            let result = try await service.selectProgram(detail.id, for: currentUser)
            switch result {
            case let .switched(updatedUser):
                self.currentUser = updatedUser
                dismiss()
                await onDataChanged(.selectedProgram)
            case let .blocked(programID, alert):
                pendingProgramID = programID
                selectionConflictAlert = alert
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeActiveSession() async {
        await mutatePresentedSession(using: service.completeActiveSession)
    }

    func cancelActiveSession() async {
        await mutatePresentedSession(using: service.cancelActiveSession)
    }

    func finishSessionAndSelectPendingProgram() async {
        await resolveSelectionConflict(using: .finishSession)
    }

    func cancelSessionAndSelectPendingProgram() async {
        await resolveSelectionConflict(using: .cancelSession)
    }

    func cancelSelectionConflict() {
        pendingProgramID = nil
        selectionConflictAlert = nil
    }

    private func mutatePresentedSession(
        using mutation: (UUID, UUID) async throws -> Bool
    ) async {
        guard let detail = presentedDetail,
              let currentUser else {
            return
        }

        do {
            let didMutate = try await mutation(detail.id, currentUser.id)
            guard didMutate else { return }
            dismiss()
            await onDataChanged(.workoutSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveSelectionConflict(
        using resolution: ProgramDetailConflictResolution
    ) async {
        guard let pendingProgramID,
              let currentUser else {
            return
        }

        do {
            self.currentUser = try await service.resolveSelectionConflict(
                selecting: pendingProgramID,
                for: currentUser,
                resolution: resolution
            )
            cancelSelectionConflict()
            await onDataChanged(.selectedProgram)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
