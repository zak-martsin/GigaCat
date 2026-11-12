import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct RemoteTrainingProfileTests {
    @Test(arguments: ["bootstrap", "refresh", "acknowledgement", "recovery"])
    func everyRemoteEntryPointRecalculatesActiveTargetsAndPreservesHistory(path: String) async throws {
        let fixture = try TrainingSessionFixture()
        let repository = fixture.factory.workoutRepository
        let history = try await fixture.start()
        let completed = try await repository.completeSession(
            sessionId: history.id, userId: fixture.user.id, completedAt: Date(timeIntervalSince1970: 1050)
        )
        for number in 1...4 { _ = try await repository.saveSet(fixture.input(setNumber: number)) }
        let active = try #require(try await repository.activeSession(for: fixture.user.id))
        let logs = try await repository.fetchExerciseLogs(sessionId: active.id)
        let remote = fixture.user.updatingTraining(goal: .maintain, level: .advanced)
        let outbox = fixture.factory.syncOutboxRepository
        var iterator = fixture.factory.profileChanges.changes().makeAsyncIterator()
        switch path {
        case "acknowledgement", "recovery":
            _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: nil)
            let operation = try #require(try outbox.claimNextReadyOperation(for: fixture.user.id, now: Date()))
            if path == "acknowledgement" {
                try outbox.complete(operation, with: .userProfile(remote))
            } else {
                try outbox.failPermanently(operation, message: "Rejected")
                let service = ProfileSyncRecoveryService(
                    remoteRepository: RemoteTrainingProfileStub(profileValue: remote),
                    userRepository: fixture.factory.userRepository, outboxRepository: outbox,
                    syncCoordinator: RemoteTrainingSyncStub()
                )
                #expect(try await service.discardFailedLocalChange(for: fixture.user.id))
            }
        default:
            let service = bootstrapper(fixture: fixture, remote: remote)
            if path == "bootstrap" { try await service.bootstrapProfile(for: fixture.user.id) } else {
                #expect(try await service.refreshProfile(for: fixture.user.id))
            }
        }
        #expect(await iterator.next() == fixture.user.id)
        let updated = try #require(try await repository.activeSession(for: fixture.user.id))
        #expect(updated.exerciseTargets?.map(\.targetSets) == [3, 5, 3])
        #expect(updated.startedAt == active.startedAt && updated.isActive)
        #expect(try await repository.fetchExerciseLogs(sessionId: active.id) == logs)
        #expect(try await repository.fetchSessions(for: fixture.user.id).first { $0.id == completed.id } == completed)
        #expect(try outbox.operationCount(for: fixture.user.id) == 0)
        #expect(try await fixture.factory.userRepository.user(id: fixture.user.id) == remote)
        // Identical pulls must neither enqueue work nor publish another change.
        let snapshot = try await fixture.factory.userRepository.profileSnapshot(for: fixture.user.id)
        #expect(try await !fixture.factory.userRepository.applyFetchedProfile(remote, ifUnchangedSince: snapshot))
        let sentinel = UUID()
        fixture.factory.profileChanges.publish(userID: sentinel)
        #expect(await iterator.next() == sentinel)
    }

    @Test
    func resetFromServerUsesTwoSetsAndKeepsOverrides() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        let remote = fixture.user.updatingTraining(goal: nil, level: nil)
        #expect(try await bootstrapper(fixture: fixture, remote: remote).refreshProfile(for: fixture.user.id))
        let active = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(active.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
    }

    @Test
    func metadataOnlyChangesDoNotInitializeOrRecalculateLegacyTargets() async throws {
        let fixture = try TrainingSessionFixture()
        let legacy = try WorkoutSession(userId: fixture.user.id, workoutDayId: fixture.day.id)
        let entity = WorkoutSessionMapper.toEntity(legacy)
        fixture.stack.mainContext.insert(entity)
        try fixture.stack.mainContext.save()
        let remote = User(
            id: fixture.user.id, selectedProgramId: fixture.day.programId,
            goal: fixture.user.goal, level: fixture.user.level, avatarPath: nil,
            createdAt: fixture.user.createdAt, updatedAt: Date()
        )
        #expect(try await bootstrapper(fixture: fixture, remote: remote).refreshProfile(for: fixture.user.id))
        #expect(entity.exerciseTargets == nil)
    }

    @Test(arguments: [false, true])
    func unresolvedLocalIntentBlocksServerChanges(terminal: Bool) async throws {
        let fixture = try TrainingSessionFixture()
        let active = try await fixture.start()
        _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: nil)
        if terminal {
            let operation = try #require(
                try fixture.factory.syncOutboxRepository.claimNextReadyOperation(for: fixture.user.id, now: Date())
            )
            try fixture.factory.syncOutboxRepository.failPermanently(operation, message: "Rejected")
        }
        let remote = fixture.user.updatingTraining(goal: nil, level: nil)
        #expect(try await !bootstrapper(fixture: fixture, remote: remote).refreshProfile(for: fixture.user.id))
        #expect(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id) == active)
        #expect(try fixture.factory.syncOutboxRepository.operationCount(for: fixture.user.id) == 1)
    }

    private func bootstrapper(fixture: TrainingSessionFixture, remote: User) -> ProfileBootstrapService {
        ProfileBootstrapService(
            remoteRepository: RemoteTrainingProfileStub(profileValue: remote),
            userRepository: fixture.factory.userRepository, outboxRepository: fixture.factory.syncOutboxRepository
        )
    }
}

struct RemoteTrainingProfileStub: UserProfileRemoteRepository {
    let profileValue: User
    func profile(for _: UUID) -> User { profileValue }
    func updateProfile(for _: UUID, selectedProgramID _: UUID?, personalization _: ProfilePersonalization?) -> User { profileValue }
}

@MainActor
final class RemoteTrainingSyncStub: SyncCoordinating {
    func activate(for _: UUID) async {}
    func deactivate() async {}
    func requestSync() async {}
}
