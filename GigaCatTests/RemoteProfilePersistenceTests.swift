import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct RemoteProfilePersistenceTests {
    @Test(arguments: ["pull", "acknowledgement", "recovery"])
    func failedRemoteSavePreservesProfileTargetsAndOutgoingIntent(path: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let original = try await prepare(at: url, path: path)
        let configuration = ModelConfiguration("GigaCat", schema: SwiftDataStack.schema, url: url, allowsSave: false)
        let container = try ModelContainer(for: SwiftDataStack.schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        let repository = LocalUserRepository(
            context: container.mainContext, currentUserIDProvider: CurrentUserContext(userID: original.user.id)
        )
        let outbox = LocalSyncOutboxRepository(context: container.mainContext)
        let remote = original.user.updatingTraining(goal: nil, level: nil)
        let snapshot = try await repository.profileSnapshot(for: original.user.id)
        do {
            switch path {
            case "acknowledgement":
                try outbox.complete(#require(original.operation), with: .userProfile(remote))
            case "recovery":
                _ = try await repository.discardFailedProfileChanges(applying: remote, ifUnchangedSince: snapshot)
            default:
                _ = try await repository.applyFetchedProfile(remote, ifUnchangedSince: snapshot)
            }
            Issue.record("A read-only store unexpectedly accepted a remote profile write")
        } catch {
            #expect(try await repository.user(id: original.user.id) == original.user)
            let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSessionEntity>())
            #expect(sessions.first?.exerciseTargets == original.session.exerciseTargets)
            let operations = try container.mainContext.fetch(FetchDescriptor<SyncOperationEntity>())
            #expect(operations.count == (original.operation == nil ? 0 : 1))
            if let expected = original.operation {
                #expect(operations.first?.id == expected.id)
                #expect(operations.first?.payload == expected.payload)
                #expect(operations.first?.revision == expected.revision)
                #expect(operations.first?.statusRawValue == expected.status.rawValue)
            }
        }
    }

    @Test
    func interruptedOutboxSurvivesRestartAndCanonicalResponseUpdatesSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let original = try await prepare(at: url, path: "acknowledgement")
        let stack = try SwiftDataStack(storeURL: url)
        let factory = LocalRepositoryFactory(stack: stack, currentUserIDProvider: CurrentUserContext(userID: original.user.id))
        let canonical = original.user.updatingTraining(goal: .maintain, level: .advanced)
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: SupabaseSyncExecutor(profileRepository: RemoteTrainingProfileStub(profileValue: canonical))
        )
        await worker.activate(for: original.user.id)
        #expect(try await factory.userRepository.currentUser() == canonical)
        #expect(try factory.syncOutboxRepository.operationCount(for: original.user.id) == 0)
        let session = try #require(try await factory.workoutRepository.activeSession(for: original.user.id))
        #expect(session.exerciseTargets?.map(\.targetSets) == [3, 5, 3])
        await worker.deactivate()
    }

    private func prepare(at url: URL, path: String) async throws -> RemoteProfileStoreSnapshot {
        let fixture = try TrainingSessionFixture(storeURL: url)
        let session = try await fixture.start()
        var operation: SyncOperation?
        if path != "pull" {
            _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: nil)
            operation = try fixture.factory.syncOutboxRepository.claimNextReadyOperation(for: fixture.user.id, now: Date())
            if path == "recovery", let claimed = operation {
                try fixture.factory.syncOutboxRepository.failPermanently(claimed, message: "Rejected")
                operation = SyncOperation(
                    id: claimed.id, userID: claimed.userID, aggregateType: claimed.aggregateType,
                    aggregateID: claimed.aggregateID, mutation: claimed.mutation, payload: claimed.payload,
                    revision: claimed.revision, status: .failed, createdAt: claimed.createdAt,
                    attemptCount: claimed.attemptCount + 1, nextAttemptAt: nil
                )
            }
        }
        return RemoteProfileStoreSnapshot(
            user: try #require(try await fixture.factory.userRepository.currentUser()), session: session, operation: operation
        )
    }
}

private struct RemoteProfileStoreSnapshot {
    let user: User
    let session: WorkoutSession
    let operation: SyncOperation?
}
