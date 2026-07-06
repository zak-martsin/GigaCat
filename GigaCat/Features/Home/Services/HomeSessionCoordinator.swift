import Foundation

/// Coordinates Home-triggered session decisions and repository mutations.
protocol HomeSessionCoordinating: Sendable {
    func selectProgram(
        id: UUID,
        currentUser: User,
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeProgramSelectionResult

    func handleMiniPlayerAction(
        currentUser: User?,
        miniPlayerContext: MiniPlayerContext
    ) -> HomeMiniPlayerActionResult

    func completeExpiredSession(
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeSessionMutationResult

    func completeActiveSessionAndSelectPendingProgram(
        miniPlayerContext: MiniPlayerContext,
        pendingProgramSelectionID: UUID?,
        currentUser: User?
    ) async throws -> HomeSessionMutationResult

    func cancelActiveSessionAndSelectPendingProgram(
        miniPlayerContext: MiniPlayerContext,
        pendingProgramSelectionID: UUID?,
        currentUser: User?
    ) async throws -> HomeSessionMutationResult

    func completePresentedProgramSession(
        presentedProgramDetail: ProgramDetail?,
        miniPlayerContext: MiniPlayerContext,
        selectedProgram: SelectedProgramSummary?
    ) async throws -> HomeSessionMutationResult

    func deletePresentedProgramSession(
        presentedProgramDetail: ProgramDetail?,
        miniPlayerContext: MiniPlayerContext,
        selectedProgram: SelectedProgramSummary?
    ) async throws -> HomeSessionMutationResult

    func deleteExpiredSession(
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeSessionMutationResult
}

/// Keeps session branching logic out of `HomeViewModel` so flows remain testable and focused.
struct HomeSessionCoordinator: HomeSessionCoordinating {
    private let userRepository: UserRepository
    private let workoutRepository: WorkoutRepository
    private let alertBuilder: HomeAlertBuilding

    init(
        userRepository: UserRepository,
        workoutRepository: WorkoutRepository,
        alertBuilder: HomeAlertBuilding = HomeAlertBuilder()
    ) {
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        self.alertBuilder = alertBuilder
    }

    func selectProgram(
        id: UUID,
        currentUser: User,
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeProgramSelectionResult {
        if case let .activeSession(session, activeProgramTitle, workoutDayTitle, _) = miniPlayerContext,
           currentUser.selectedProgramId != id {
            let alert = alertBuilder.makeProgramSelectionConflictAlert(
                sessionID: session.id,
                currentProgramTitle: activeProgramTitle,
                currentWorkoutDayTitle: workoutDayTitle
            )
            return .blocked(pendingProgramSelectionID: id, alert: alert)
        }

        let updatedUser = try await userRepository.updateSelectedProgram(for: currentUser.id, programId: id)
        return .switched(updatedUser)
    }

    func handleMiniPlayerAction(
        currentUser: User?,
        miniPlayerContext: MiniPlayerContext
    ) -> HomeMiniPlayerActionResult {
        guard currentUser != nil else {
            return HomeMiniPlayerActionResult(route: .none, expiredSessionAlert: nil)
        }

        switch miniPlayerContext {
        case .noProgramSelected:
            return HomeMiniPlayerActionResult(route: .none, expiredSessionAlert: nil)
        case .readyToStart:
            return HomeMiniPlayerActionResult(route: .openWorkout, expiredSessionAlert: nil)
        case let .activeSession(session, programTitle, workoutDayTitle, isExpired):
            guard isExpired else {
                return HomeMiniPlayerActionResult(route: .openWorkout, expiredSessionAlert: nil)
            }

            let alert = alertBuilder.makeExpiredSessionAlert(
                sessionID: session.id,
                programTitle: programTitle,
                workoutDayTitle: workoutDayTitle
            )
            return HomeMiniPlayerActionResult(route: .none, expiredSessionAlert: alert)
        }
    }

    func completeExpiredSession(
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeSessionMutationResult {
        guard case let .activeSession(session, _, _, _) = miniPlayerContext else {
            return .noChange
        }

        _ = try await workoutRepository.completeSession(
            sessionId: session.id,
            completedAt: Date()
        )

        return HomeSessionMutationResult(
            updatedUser: nil,
            shouldReload: true,
            shouldDismissProgramDetail: false,
            clearedExpiredSessionAlert: true,
            clearedProgramSelectionConflictAlert: false,
            clearedPendingProgramSelectionID: false
        )
    }

    func completeActiveSessionAndSelectPendingProgram(
        miniPlayerContext: MiniPlayerContext,
        pendingProgramSelectionID: UUID?,
        currentUser: User?
    ) async throws -> HomeSessionMutationResult {
        guard case let .activeSession(session, _, _, _) = miniPlayerContext,
              let pendingProgramSelectionID,
              let currentUser else {
            return .noChange
        }

        let updatedUser = try await workoutRepository.completeSessionAndSelectProgram(
            sessionId: session.id,
            completedAt: Date(),
            userId: currentUser.id,
            programId: pendingProgramSelectionID
        )

        return HomeSessionMutationResult(
            updatedUser: updatedUser,
            shouldReload: true,
            shouldDismissProgramDetail: true,
            clearedExpiredSessionAlert: false,
            clearedProgramSelectionConflictAlert: true,
            clearedPendingProgramSelectionID: true
        )
    }

    func cancelActiveSessionAndSelectPendingProgram(
        miniPlayerContext: MiniPlayerContext,
        pendingProgramSelectionID: UUID?,
        currentUser: User?
    ) async throws -> HomeSessionMutationResult {
        guard case let .activeSession(session, _, _, _) = miniPlayerContext,
              let pendingProgramSelectionID,
              let currentUser else {
            return .noChange
        }

        let updatedUser = try await workoutRepository.deleteSessionAndSelectProgram(
            sessionId: session.id,
            userId: currentUser.id,
            programId: pendingProgramSelectionID
        )

        return HomeSessionMutationResult(
            updatedUser: updatedUser,
            shouldReload: true,
            shouldDismissProgramDetail: true,
            clearedExpiredSessionAlert: false,
            clearedProgramSelectionConflictAlert: true,
            clearedPendingProgramSelectionID: true
        )
    }

    func completePresentedProgramSession(
        presentedProgramDetail: ProgramDetail?,
        miniPlayerContext: MiniPlayerContext,
        selectedProgram: SelectedProgramSummary?
    ) async throws -> HomeSessionMutationResult {
        guard let session = activeSessionForPresentedProgram(
            presentedProgramDetail: presentedProgramDetail,
            miniPlayerContext: miniPlayerContext,
            selectedProgram: selectedProgram
        ) else {
            return .noChange
        }

        _ = try await workoutRepository.completeSession(
            sessionId: session.id,
            completedAt: Date()
        )

        return HomeSessionMutationResult(
            updatedUser: nil,
            shouldReload: true,
            shouldDismissProgramDetail: true,
            clearedExpiredSessionAlert: false,
            clearedProgramSelectionConflictAlert: false,
            clearedPendingProgramSelectionID: false
        )
    }

    func deletePresentedProgramSession(
        presentedProgramDetail: ProgramDetail?,
        miniPlayerContext: MiniPlayerContext,
        selectedProgram: SelectedProgramSummary?
    ) async throws -> HomeSessionMutationResult {
        guard let session = activeSessionForPresentedProgram(
            presentedProgramDetail: presentedProgramDetail,
            miniPlayerContext: miniPlayerContext,
            selectedProgram: selectedProgram
        ) else {
            return .noChange
        }

        try await workoutRepository.deleteSession(sessionId: session.id)

        return HomeSessionMutationResult(
            updatedUser: nil,
            shouldReload: true,
            shouldDismissProgramDetail: true,
            clearedExpiredSessionAlert: false,
            clearedProgramSelectionConflictAlert: false,
            clearedPendingProgramSelectionID: false
        )
    }

    func deleteExpiredSession(
        miniPlayerContext: MiniPlayerContext
    ) async throws -> HomeSessionMutationResult {
        guard case let .activeSession(session, _, _, _) = miniPlayerContext else {
            return .noChange
        }

        try await workoutRepository.deleteSession(sessionId: session.id)

        return HomeSessionMutationResult(
            updatedUser: nil,
            shouldReload: true,
            shouldDismissProgramDetail: false,
            clearedExpiredSessionAlert: true,
            clearedProgramSelectionConflictAlert: false,
            clearedPendingProgramSelectionID: false
        )
    }

    /// Returns the active session only when the presented detail sheet refers to the currently selected program.
    private func activeSessionForPresentedProgram(
        presentedProgramDetail: ProgramDetail?,
        miniPlayerContext: MiniPlayerContext,
        selectedProgram: SelectedProgramSummary?
    ) -> WorkoutSession? {
        guard let presentedProgramDetail,
              presentedProgramDetail.hasActiveSession,
              case let .activeSession(session, _, _, _) = miniPlayerContext,
              selectedProgram?.id == presentedProgramDetail.id else {
            return nil
        }

        return session
    }
}

private extension HomeSessionMutationResult {
    static let noChange = HomeSessionMutationResult(
        updatedUser: nil,
        shouldReload: false,
        shouldDismissProgramDetail: false,
        clearedExpiredSessionAlert: false,
        clearedProgramSelectionConflictAlert: false,
        clearedPendingProgramSelectionID: false
    )
}
