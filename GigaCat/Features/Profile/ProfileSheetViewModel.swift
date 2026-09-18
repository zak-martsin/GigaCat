import Combine
import Foundation

/// Presents profile synchronization state without exposing outbox errors to the user.
@MainActor
final class ProfileSheetViewModel: ObservableObject {
    @Published private(set) var isSyncFailureVisible = false

    private let recoveryService: any ProfileSyncRecovering
    private let userID: UUID

    init(recoveryService: any ProfileSyncRecovering, userID: UUID) {
        self.recoveryService = recoveryService
        self.userID = userID
    }

    /// Returns true only when a newly observed terminal failure needs a brief notice.
    @discardableResult
    func refreshSyncStatus() -> Bool {
        guard let status = try? recoveryService.status(for: userID) else {
            return false
        }

        let wasFailed = isSyncFailureVisible
        if case .failed = status {
            isSyncFailureVisible = true
        } else {
            isSyncFailureVisible = false
        }
        return isSyncFailureVisible && !wasFailed
    }
}
