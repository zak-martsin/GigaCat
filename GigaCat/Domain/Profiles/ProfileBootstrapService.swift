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
        let localSnapshot = try await userRepository.profileSnapshot(for: userID)
        let hasUnresolvedChange = try outboxRepository
            .hasUnresolvedProfileOperation(for: userID)
        let remoteProfile: User

        do {
            remoteProfile = try await remoteRepository.profile(for: userID)
        } catch {
            guard localSnapshot.user == nil else { return }
            _ = try await userRepository.applyFetchedProfile(
                User(
                    id: userID,
                    createdAt: .distantPast,
                    updatedAt: .distantPast
                ),
                ifUnchangedSince: localSnapshot
            )
            return
        }

        guard !hasUnresolvedChange else { return }
        _ = try await userRepository.applyFetchedProfile(
            remoteProfile,
            ifUnchangedSince: localSnapshot
        )
    }

    func refreshProfile(for userID: UUID) async throws -> Bool {
        let localSnapshot = try await userRepository.profileSnapshot(for: userID)
        let hasUnresolvedChange = try outboxRepository
            .hasUnresolvedProfileOperation(for: userID)

        guard !hasUnresolvedChange else { return false }

        let remoteProfile: User
        do {
            remoteProfile = try await remoteRepository.profile(for: userID)
        } catch {
            return false
        }

        return try await userRepository.applyFetchedProfile(
            remoteProfile,
            ifUnchangedSince: localSnapshot
        )
    }
}
