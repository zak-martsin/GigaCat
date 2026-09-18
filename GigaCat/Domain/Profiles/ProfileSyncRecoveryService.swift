import Foundation

/// Exposes terminal profile-sync recovery without leaking the outbox into UI code.
@MainActor
protocol ProfileSyncRecovering {
    func status(for userID: UUID) throws -> ProfileSyncStatus
    func retryFailedChange(for userID: UUID) async throws
    func discardFailedLocalChange(for userID: UUID) async throws -> Bool
}

@MainActor
struct ProfileSyncRecoveryService: ProfileSyncRecovering {
    private let remoteRepository: any UserProfileRemoteRepository
    private let userRepository: any UserRepository
    private let outboxRepository: any SyncOutboxRepository
    private let syncCoordinator: any SyncCoordinating

    init(
        remoteRepository: any UserProfileRemoteRepository,
        userRepository: any UserRepository,
        outboxRepository: any SyncOutboxRepository,
        syncCoordinator: any SyncCoordinating
    ) {
        self.remoteRepository = remoteRepository
        self.userRepository = userRepository
        self.outboxRepository = outboxRepository
        self.syncCoordinator = syncCoordinator
    }

    func status(for userID: UUID) throws -> ProfileSyncStatus {
        try outboxRepository.profileSyncStatus(for: userID)
    }

    func retryFailedChange(for userID: UUID) async throws {
        guard try outboxRepository.retryFailedProfileOperation(for: userID) else {
            return
        }
        await syncCoordinator.requestSync()
    }

    /// Pulls first so a failed offline recovery never discards the only durable local intent.
    func discardFailedLocalChange(for userID: UUID) async throws -> Bool {
        guard case .failed = try status(for: userID) else { return false }

        let localProfile = try await userRepository.user(id: userID)
        let remoteProfile = try await remoteRepository.profile(for: userID)
        let didChange = localProfile != remoteProfile

        if didChange {
            try await userRepository.save(remoteProfile)
        }

        _ = try outboxRepository.removeFailedProfileOperations(for: userID)
        return didChange
    }
}
