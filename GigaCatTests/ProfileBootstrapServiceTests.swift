import Foundation
import Testing
@testable import GigaCat

@MainActor
struct ProfileBootstrapServiceTests {

    @Test
    func savesRemoteProfileWhenNoLocalProfileExists() async throws {
        let remoteProfile = User(
            id: UUID(),
            selectedProgramId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = UserRepositorySpy()
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(profile: remoteProfile),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        try await service.bootstrapProfile(for: remoteProfile.id)

        #expect(repository.savedUsers() == [remoteProfile])
    }

    @Test
    func bootstrapUsesRemoteProfileEvenWhenLocalTimestampIsNewer() async throws {
        let userID = UUID()
        let localProfile = User(
            id: userID,
            selectedProgramId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let remoteProfile = User(
            id: userID,
            selectedProgramId: nil,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = UserRepositorySpy(user: localProfile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(profile: remoteProfile),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        try await service.bootstrapProfile(for: userID)

        #expect(repository.savedUsers() == [remoteProfile])
    }

    @Test
    func createsMinimalLocalProfileWhenRemoteIsUnavailable() async throws {
        let userID = UUID()
        let repository = UserRepositorySpy()
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(error: .unavailable),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        try await service.bootstrapProfile(for: userID)

        let savedUser = try #require(repository.savedUsers().first)
        #expect(savedUser.id == userID)
        #expect(savedUser.selectedProgramId == nil)
    }

    @Test
    func leavesExistingLocalProfileUntouchedWhenRemoteIsUnavailable() async throws {
        let localProfile = User(id: UUID(), selectedProgramId: UUID())
        let repository = UserRepositorySpy(user: localProfile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(error: .unavailable),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        try await service.bootstrapProfile(for: localProfile.id)

        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func pendingLocalChangeIsNotOverwrittenByNewerRemoteProfile() async throws {
        let userID = UUID()
        let localProfile = User(
            id: userID,
            selectedProgramId: UUID(),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let remoteProfile = User(
            id: userID,
            selectedProgramId: nil,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = UserRepositorySpy(user: localProfile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(profile: remoteProfile),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub(hasPendingProfileOperation: true)
        )

        try await service.bootstrapProfile(for: userID)

        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func refreshUsesRemoteProfileEvenWhenLocalTimestampIsNewer() async throws {
        let userID = UUID()
        let localProfile = User(
            id: userID,
            selectedProgramId: nil,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let remoteProfile = User(
            id: userID,
            selectedProgramId: UUID(),
            createdAt: localProfile.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = UserRepositorySpy(user: localProfile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(profile: remoteProfile),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        let didChange = try await service.refreshProfile(for: userID)

        #expect(didChange)
        #expect(repository.savedUsers() == [remoteProfile])
    }

    @Test
    func refreshReturnsFalseForUnchangedProfile() async throws {
        let profile = User(id: UUID(), selectedProgramId: UUID())
        let repository = UserRepositorySpy(user: profile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(profile: profile),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        let didChange = try await service.refreshProfile(for: profile.id)

        #expect(!didChange)
        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func refreshReturnsFalseWhenRemoteIsUnavailable() async throws {
        let profile = User(id: UUID(), selectedProgramId: UUID())
        let repository = UserRepositorySpy(user: profile)
        let service = ProfileBootstrapService(
            remoteRepository: UserProfileRemoteRepositoryStub(error: .unavailable),
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub()
        )

        let didChange = try await service.refreshProfile(for: profile.id)

        #expect(!didChange)
        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func refreshDoesNotLoadRemoteProfileWhileLocalChangeIsPending() async throws {
        let profile = User(id: UUID(), selectedProgramId: UUID())
        let remoteRepository = UserProfileRemoteRepositorySpy(profile: profile)
        let repository = UserRepositorySpy(user: profile)
        let service = ProfileBootstrapService(
            remoteRepository: remoteRepository,
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub(hasPendingProfileOperation: true)
        )

        let didChange = try await service.refreshProfile(for: profile.id)

        #expect(!didChange)
        #expect(await remoteRepository.profileRequestCount == 0)
        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func refreshDoesNotOverwriteLocalProfileWhileFailureAwaitsUserDecision() async throws {
        let profile = User(id: UUID(), selectedProgramId: UUID())
        let remoteRepository = UserProfileRemoteRepositorySpy(profile: profile)
        let repository = UserRepositorySpy(user: profile)
        let service = ProfileBootstrapService(
            remoteRepository: remoteRepository,
            userRepository: repository,
            outboxRepository: SyncOutboxRepositoryStub(
                hasUnresolvedProfileOperation: true
            )
        )

        let didChange = try await service.refreshProfile(for: profile.id)

        #expect(!didChange)
        #expect(await remoteRepository.profileRequestCount == 0)
        #expect(repository.savedUsers().isEmpty)
    }

    @Test
    func refreshDoesNotOverwriteSelectionMadeDuringRemoteFetch() async throws {
        let fixture = try LocalProfileFixture()
        let factory = fixture.factory
        let userID = fixture.userID
        let programID = fixture.programID
        let oldProfile = try #require(await factory.userRepository.user(id: userID))
        let remote = BlockingUserProfileRemoteRepository(
            profile: staleRemoteProfile(after: oldProfile)
        )
        let service = ProfileBootstrapService(
            remoteRepository: remote,
            userRepository: factory.userRepository,
            outboxRepository: factory.syncOutboxRepository
        )

        let refresh = Task { try await service.refreshProfile(for: userID) }
        await remote.waitUntilFetchStarts()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: programID
        )
        await remote.releaseFetch()

        #expect(try await !refresh.value)
        #expect(try await factory.userRepository.user(id: userID)?.selectedProgramId == programID)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 1)
    }

    @Test
    func refreshRejectsOldResponseEvenWhenNewOutboxOperationAlreadyCompleted() async throws {
        let fixture = try LocalProfileFixture()
        let factory = fixture.factory
        let userID = fixture.userID
        let programID = fixture.programID
        let oldProfile = try #require(await factory.userRepository.user(id: userID))
        let remote = BlockingUserProfileRemoteRepository(
            profile: staleRemoteProfile(after: oldProfile)
        )
        let service = ProfileBootstrapService(
            remoteRepository: remote,
            userRepository: factory.userRepository,
            outboxRepository: factory.syncOutboxRepository
        )

        let refresh = Task { try await service.refreshProfile(for: userID) }
        await remote.waitUntilFetchStarts()
        let selectedProfile = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: programID
        )
        let operation = try #require(
            try factory.syncOutboxRepository.claimNextReadyOperation(for: userID, now: Date())
        )
        try factory.syncOutboxRepository.complete(
            operation,
            with: .userProfile(selectedProfile)
        )
        await remote.releaseFetch()

        #expect(try await !refresh.value)
        #expect(try await factory.userRepository.user(id: userID)?.selectedProgramId == programID)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 0)
    }

    @Test
    func bootstrapDoesNotOverwriteSelectionMadeDuringRemoteFetch() async throws {
        let fixture = try LocalProfileFixture()
        let factory = fixture.factory
        let userID = fixture.userID
        let programID = fixture.programID
        let oldProfile = try #require(await factory.userRepository.user(id: userID))
        let remote = BlockingUserProfileRemoteRepository(
            profile: staleRemoteProfile(after: oldProfile)
        )
        let service = ProfileBootstrapService(
            remoteRepository: remote,
            userRepository: factory.userRepository,
            outboxRepository: factory.syncOutboxRepository
        )

        let bootstrap = Task { try await service.bootstrapProfile(for: userID) }
        await remote.waitUntilFetchStarts()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: programID
        )
        await remote.releaseFetch()
        try await bootstrap.value

        #expect(try await factory.userRepository.user(id: userID)?.selectedProgramId == programID)
    }

    private func staleRemoteProfile(after profile: User) -> User {
        User(
            id: profile.id,
            selectedProgramId: profile.selectedProgramId,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt.addingTimeInterval(1)
        )
    }

}

private struct UserProfileRemoteRepositoryStub: UserProfileRemoteRepository {
    private let result: Result<User, ProfileProviderTestError>

    init(profile: User) {
        result = .success(profile)
    }

    init(error: ProfileProviderTestError) {
        result = .failure(error)
    }

    func profile(for _: UUID) throws -> User {
        try result.get()
    }

    func updateProfile(for _: UUID, selectedProgramID _: UUID?) throws -> User {
        try result.get()
    }
}

private actor UserProfileRemoteRepositorySpy: UserProfileRemoteRepository {
    private let profile: User
    private(set) var profileRequestCount = 0

    init(profile: User) {
        self.profile = profile
    }

    func profile(for _: UUID) -> User {
        profileRequestCount += 1
        return profile
    }

    func updateProfile(for _: UUID, selectedProgramID _: UUID?) -> User {
        profile
    }
}

@MainActor
private final class SyncOutboxRepositoryStub: SyncOutboxRepository {
    private let hasPendingProfileOperation: Bool
    private let hasUnresolvedProfileOperation: Bool

    init(
        hasPendingProfileOperation: Bool = false,
        hasUnresolvedProfileOperation: Bool? = nil
    ) {
        self.hasPendingProfileOperation = hasPendingProfileOperation
        self.hasUnresolvedProfileOperation = hasUnresolvedProfileOperation
            ?? hasPendingProfileOperation
    }

    func recoverInterruptedOperations(for _: UUID) {}

    func claimNextReadyOperation(for _: UUID, now _: Date) -> SyncOperation? {
        nil
    }

    func complete(_: SyncOperation, with _: SyncExecutionResult) {}

    func fail(_: SyncOperation, message _: String, retryAt _: Date) {}

    func pauseForAuthentication(_: SyncOperation, message _: String) {}

    func failPermanently(_: SyncOperation, message _: String) {}

    func hasReadyOperations(for _: UUID, now _: Date) -> Bool {
        false
    }

    func nextRetryDate(for _: UUID, after _: Date) -> Date? {
        nil
    }

    func hasUnfinishedProfileOperation(for _: UUID) -> Bool {
        hasPendingProfileOperation
    }

    func hasUnresolvedProfileOperation(for _: UUID) -> Bool {
        hasUnresolvedProfileOperation
    }

    func profileSyncStatus(for _: UUID) -> ProfileSyncStatus {
        hasPendingProfileOperation ? .waiting : .synchronized
    }

    func retryFailedProfileOperation(for _: UUID) -> Bool {
        false
    }

    func removeFailedProfileOperations(for _: UUID) -> Bool {
        false
    }
}

@MainActor
private final class UserRepositorySpy: UserRepository {
    private var storedUser: User?
    private var receivedUsers: [User] = []
    private var revision: Int?

    init(user: User? = nil) {
        storedUser = user
        revision = user == nil ? nil : 0
    }

    func currentUser() -> User? {
        storedUser
    }

    func user(id: UUID) -> User? {
        guard storedUser?.id == id else { return nil }
        return storedUser
    }

    func save(_ user: User) {
        storedUser = user
        revision = revision ?? 0
        receivedUsers.append(user)
    }

    func profileSnapshot(for userID: UUID) -> LocalProfileSnapshot {
        LocalProfileSnapshot(
            userID: userID,
            user: storedUser?.id == userID ? storedUser : nil,
            revision: storedUser?.id == userID ? revision : nil
        )
    }

    func applyFetchedProfile(
        _ user: User,
        ifUnchangedSince snapshot: LocalProfileSnapshot
    ) -> Bool {
        guard user.id == snapshot.userID,
              revision == snapshot.revision,
              storedUser == snapshot.user,
              storedUser != user else {
            return false
        }
        save(user)
        return true
    }

    func updateSelectedProgram(for userId: UUID, programId: UUID?) throws -> User {
        guard let storedUser,
              storedUser.id == userId else {
            throw RepositoryError.userNotFound
        }

        let updatedUser = storedUser.selectingProgram(programId)
        self.storedUser = updatedUser
        revision = (revision ?? 0) + 1
        return updatedUser
    }

    func savedUsers() -> [User] {
        receivedUsers
    }
}

private enum ProfileProviderTestError: Error {
    case unavailable
}
