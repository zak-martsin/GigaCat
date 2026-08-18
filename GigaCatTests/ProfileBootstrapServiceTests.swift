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

        #expect(await repository.savedUsers() == [remoteProfile])
    }

    @Test
    func keepsNewerLocalProfile() async throws {
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

        #expect(await repository.savedUsers().isEmpty)
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

        let savedUser = try #require(await repository.savedUsers().first)
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

        #expect(await repository.savedUsers().isEmpty)
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

        #expect(await repository.savedUsers().isEmpty)
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

@MainActor
private final class SyncOutboxRepositoryStub: SyncOutboxRepository {
    private let hasPendingProfileOperation: Bool

    init(hasPendingProfileOperation: Bool = false) {
        self.hasPendingProfileOperation = hasPendingProfileOperation
    }

    func recoverInterruptedOperations(for _: UUID) {}

    func claimNextReadyOperation(for _: UUID, now _: Date) -> SyncOperation? {
        nil
    }

    func complete(_: SyncOperation, with _: SyncExecutionResult) {}

    func fail(_: SyncOperation, message _: String, retryAt _: Date) {}

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
}

private actor UserRepositorySpy: UserRepository {
    private var storedUser: User?
    private var receivedUsers: [User] = []

    init(user: User? = nil) {
        storedUser = user
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
        receivedUsers.append(user)
    }

    func updateSelectedProgram(for userId: UUID, programId: UUID?) throws -> User {
        guard let storedUser,
              storedUser.id == userId else {
            throw RepositoryError.userNotFound
        }

        let updatedUser = storedUser.selectingProgram(programId)
        self.storedUser = updatedUser
        return updatedUser
    }

    func savedUsers() -> [User] {
        receivedUsers
    }
}

private enum ProfileProviderTestError: Error {
    case unavailable
}
