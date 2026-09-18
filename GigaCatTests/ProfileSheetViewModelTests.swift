import Foundation
import Testing
@testable import GigaCat

@MainActor
struct ProfileSheetViewModelTests {
    @Test
    func terminalFailureIsAnnouncedOnceAndClearsAfterSync() {
        let recovery = ProfileSyncRecoveryStub(status: .waiting)
        let viewModel = ProfileSheetViewModel(recoveryService: recovery, userID: UUID())

        #expect(!viewModel.refreshSyncStatus())
        #expect(!viewModel.isSyncFailureVisible)

        recovery.currentStatus = .failed(message: "Raw Supabase error")
        #expect(viewModel.refreshSyncStatus())
        #expect(!viewModel.refreshSyncStatus())
        #expect(viewModel.isSyncFailureVisible)

        recovery.currentStatus = .synchronized
        #expect(!viewModel.refreshSyncStatus())
        #expect(!viewModel.isSyncFailureVisible)
    }
}

@MainActor
private final class ProfileSyncRecoveryStub: ProfileSyncRecovering {
    var currentStatus: ProfileSyncStatus

    init(status: ProfileSyncStatus) {
        currentStatus = status
    }

    func status(for _: UUID) throws -> ProfileSyncStatus { currentStatus }
    func retryFailedChange(for _: UUID) async throws {}
    func discardFailedLocalChange(for _: UUID) async throws -> Bool { false }
}
