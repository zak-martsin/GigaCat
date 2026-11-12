import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct RemoteProfileRaceTests {
    @Test(arguments: [false, true])
    func localEditDuringPullOrRecoveryWins(recovery: Bool) async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        let outbox = fixture.factory.syncOutboxRepository
        if recovery {
            _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: nil)
            let operation = try #require(try outbox.claimNextReadyOperation(for: fixture.user.id, now: Date()))
            try outbox.failPermanently(operation, message: "Rejected")
        }
        let remote = BlockingUserProfileRemoteRepository(profile: fixture.user.updatingTraining(goal: nil, level: nil))
        let pull = Task {
            if recovery {
                return try await ProfileSyncRecoveryService(
                    remoteRepository: remote, userRepository: fixture.factory.userRepository,
                    outboxRepository: outbox, syncCoordinator: RemoteTrainingSyncStub()
                ).discardFailedLocalChange(for: fixture.user.id)
            }
            return try await ProfileBootstrapService(
                remoteRepository: remote, userRepository: fixture.factory.userRepository, outboxRepository: outbox
            ).refreshProfile(for: fixture.user.id)
        }
        await remote.waitUntilFetchStarts()
        let local = try await fixture.factory.userRepository.updateTrainingPreferences(
            for: fixture.user.id, goal: .buildMuscle, level: .beginner
        )
        await remote.releaseFetch()
        #expect(try await !pull.value)
        #expect(try await fixture.factory.userRepository.user(id: fixture.user.id) == local)
        let session = try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id)
        #expect(session?.exerciseTargets?.map(\.targetSets) == [3, 5, 3])
        #expect(try outbox.operationCount(for: fixture.user.id) == 1)
    }

    @Test
    func oldAcknowledgementCannotRevertNewTrainingPreferences() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        let repository = fixture.factory.userRepository
        _ = try await repository.updateSelectedProgram(for: fixture.user.id, programId: nil)
        let outbox = fixture.factory.syncOutboxRepository
        let old = try #require(try outbox.claimNextReadyOperation(for: fixture.user.id, now: Date()))
        let local = try await repository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        try outbox.complete(old, with: .userProfile(fixture.user))
        #expect(try await repository.user(id: fixture.user.id) == local)
        let session = try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id)
        #expect(session?.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
        #expect(try outbox.operationCount(for: fixture.user.id) == 1)
    }

    @Test
    func completionDuringFetchFreezesTargetsBeforeRemoteProfileIsApplied() async throws {
        let fixture = try TrainingSessionFixture()
        let active = try await fixture.start()
        let remote = BlockingUserProfileRemoteRepository(profile: fixture.user.updatingTraining(goal: nil, level: nil))
        let service = ProfileBootstrapService(
            remoteRepository: remote, userRepository: fixture.factory.userRepository, outboxRepository: fixture.factory.syncOutboxRepository
        )
        let pull = Task { try await service.refreshProfile(for: fixture.user.id) }
        await remote.waitUntilFetchStarts()
        let completed = try await fixture.factory.workoutRepository.completeSession(
            sessionId: active.id, userId: fixture.user.id, completedAt: active.startedAt.addingTimeInterval(60)
        )
        await remote.releaseFetch()
        #expect(try await pull.value)
        #expect(try await fixture.factory.workoutRepository.fetchSessions(for: fixture.user.id) == [completed])
        #expect(completed.exerciseTargets == active.exerciseTargets)
    }

    @Test
    func accountSwitchDuringFetchRejectsTheOldAccountsResponse() async throws {
        let fixture = try TrainingSessionFixture()
        let active = try await fixture.start()
        let account = CurrentUserContext(userID: fixture.user.id)
        let repository = LocalUserRepository(context: fixture.stack.mainContext, currentUserIDProvider: account)
        let remote = BlockingUserProfileRemoteRepository(profile: fixture.user.updatingTraining(goal: nil, level: nil))
        let service = ProfileBootstrapService(
            remoteRepository: remote, userRepository: repository, outboxRepository: fixture.factory.syncOutboxRepository
        )
        let pull = Task { try await service.refreshProfile(for: fixture.user.id) }
        await remote.waitUntilFetchStarts()
        await account.setCurrentUserID(UUID())
        await remote.releaseFetch()
        #expect(try await !pull.value)
        #expect(try await repository.user(id: fixture.user.id) == fixture.user)
        #expect(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id) == active)
    }
}
