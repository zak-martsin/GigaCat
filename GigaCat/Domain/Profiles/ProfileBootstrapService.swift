import Foundation

/// Prepares the current user's local profile before authenticated features appear.
@MainActor
protocol ProfileBootstrapping {
    func bootstrapProfile(for userID: UUID) async throws
    /// Pulls the remote profile when no local mutation still needs to be pushed.
    func refreshProfile(for userID: UUID) async throws -> Bool
}

/// Refreshes a local profile when possible while preserving offline access.
@MainActor
struct ProfileBootstrapService: ProfileBootstrapping {
    private let remoteRepository: any UserProfileRemoteRepository
    private let userRepository: any UserRepository
    private let outboxRepository: any SyncOutboxRepository

    init(
        remoteRepository: any UserProfileRemoteRepository,
        userRepository: any UserRepository,
        outboxRepository: any SyncOutboxRepository
    ) {
        self.remoteRepository = remoteRepository
        self.userRepository = userRepository
        self.outboxRepository = outboxRepository
    }

    func bootstrapProfile(for userID: UUID) async throws {
        let localProfile = try await userRepository.user(id: userID)
        let hasUnresolvedChange = try outboxRepository
            .hasUnresolvedProfileOperation(for: userID)
        let remoteProfile: User

        do {
            remoteProfile = try await remoteRepository.profile(for: userID)
        } catch {
            guard localProfile == nil else { return }
            try await userRepository.save(
                User(
                    id: userID,
                    createdAt: .distantPast,
                    updatedAt: .distantPast
                )
            )
            return
        }

        guard !hasUnresolvedChange else { return }
        guard localProfile != remoteProfile else { return }

        try await userRepository.save(remoteProfile)
    }

    func refreshProfile(for userID: UUID) async throws -> Bool {
        let localProfile = try await userRepository.user(id: userID)
        let hasUnresolvedChange = try outboxRepository
            .hasUnresolvedProfileOperation(for: userID)

        guard !hasUnresolvedChange else { return false }

        let remoteProfile: User
        do {
            remoteProfile = try await remoteRepository.profile(for: userID)
        } catch {
            return false
        }

        guard localProfile != remoteProfile else { return false }

        try await userRepository.save(remoteProfile)
        return true
    }
}
