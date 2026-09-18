import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct ProfileSyncRecoveryServiceTests {
    @Test
    func retryReturnsFailedOperationToPendingAndRequestsSync() async throws {
        let fixture = try await ProfileSyncRecoveryFixture.make()
        let operation = try #require(
            try fixture.outbox.claimNextReadyOperation(
                for: fixture.userID,
                now: Date()
            )
        )
        try fixture.outbox.failPermanently(operation, message: "Rejected")
        let coordinator = ProfileSyncCoordinatorSpy()
        let service = fixture.makeService(coordinator: coordinator)

        #expect(try service.status(for: fixture.userID) == .failed(message: "Rejected"))

        try await service.retryFailedChange(for: fixture.userID)

        #expect(try service.status(for: fixture.userID) == .waiting)
        #expect(coordinator.requestCount == 1)
    }

    @Test
    func discardPullsRemoteProfileAndRemovesFailedOperation() async throws {
        let fixture = try await ProfileSyncRecoveryFixture.make()
        let operation = try #require(
            try fixture.outbox.claimNextReadyOperation(
                for: fixture.userID,
                now: Date()
            )
        )
        try fixture.outbox.failPermanently(operation, message: "Rejected")
        let remoteProfile = User(
            id: fixture.userID,
            selectedProgramId: nil,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let service = fixture.makeService(
            remoteProfile: remoteProfile,
            coordinator: ProfileSyncCoordinatorSpy()
        )

        let didChange = try await service.discardFailedLocalChange(
            for: fixture.userID
        )

        #expect(didChange)
        #expect(try service.status(for: fixture.userID) == .synchronized)
        #expect(try fixture.outbox.operationCount(for: fixture.userID) == 0)
        #expect(try await fixture.userRepository.user(id: fixture.userID) == remoteProfile)
    }

    @Test
    func newSelectionReplacesFailedOperation() async throws {
        let fixture = try await ProfileSyncRecoveryFixture.make()
        let operation = try #require(
            try fixture.outbox.claimNextReadyOperation(
                for: fixture.userID,
                now: Date()
            )
        )
        try fixture.outbox.failPermanently(operation, message: "Rejected")

        _ = try await fixture.userRepository.updateSelectedProgram(
            for: fixture.userID,
            programId: fixture.secondProgramID
        )

        let operations = try fixture.stack.mainContext.fetch(
            FetchDescriptor<SyncOperationEntity>()
        )
        let replacement = try #require(operations.first)
        let payload = try JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: replacement.payload
        )
        #expect(operations.count == 1)
        #expect(replacement.statusRawValue == SyncOperationStatus.pending.rawValue)
        #expect(replacement.lastErrorMessage == nil)
        #expect(payload.selectedProgramID == fixture.secondProgramID)
    }
}

@MainActor
private struct ProfileSyncRecoveryFixture {
    let stack: SwiftDataStack
    let userID: UUID
    let secondProgramID: UUID
    let userRepository: any UserRepository
    let outbox: LocalSyncOutboxRepository

    static func make() async throws -> Self {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let userID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        let firstProgram = try WorkoutProgram(title: "First", description: "First")
        let secondProgram = try WorkoutProgram(title: "Second", description: "Second")
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(firstProgram))
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(secondProgram))
        _ = try await factory.userRepository.currentUser()
        try stack.mainContext.save()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: firstProgram.id
        )

        return Self(
            stack: stack,
            userID: userID,
            secondProgramID: secondProgram.id,
            userRepository: factory.userRepository,
            outbox: factory.syncOutboxRepository
        )
    }

    func makeService(
        remoteProfile: User? = nil,
        coordinator: ProfileSyncCoordinatorSpy
    ) -> ProfileSyncRecoveryService {
        ProfileSyncRecoveryService(
            remoteRepository: ProfileSyncRemoteRepositoryStub(
                profile: remoteProfile ?? User(id: userID)
            ),
            userRepository: userRepository,
            outboxRepository: outbox,
            syncCoordinator: coordinator
        )
    }
}

private struct ProfileSyncRemoteRepositoryStub: UserProfileRemoteRepository {
    let profile: User

    func profile(for _: UUID) -> User {
        profile
    }

    func updateProfile(for _: UUID, selectedProgramID _: UUID?) -> User {
        profile
    }
}

@MainActor
private final class ProfileSyncCoordinatorSpy: SyncCoordinating {
    private(set) var requestCount = 0

    func activate(for _: UUID) async {}
    func deactivate() async {}

    func requestSync() async {
        requestCount += 1
    }
}
