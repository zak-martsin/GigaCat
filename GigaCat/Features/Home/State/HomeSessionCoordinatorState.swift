import Foundation

/// Result of a program selection attempt from Home.
enum HomeProgramSelectionResult {
    case switched(User)
    case blocked(pendingProgramSelectionID: UUID, alert: ProgramSelectionConflictAlert)
}

/// Output of a mini player tap after Home resolves session rules.
struct HomeMiniPlayerActionResult {
    let route: MiniPlayerRoute
    let expiredSessionAlert: ExpiredSessionAlert?
}

/// Describes which Home state should be updated after a session mutation completes.
struct HomeSessionMutationResult {
    let updatedUser: User?
    let shouldReload: Bool
    let shouldDismissProgramDetail: Bool
    let clearedExpiredSessionAlert: Bool
    let clearedProgramSelectionConflictAlert: Bool
    let clearedPendingProgramSelectionID: Bool
}
