import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct SyncWorkerTests {

    @Test
    func newerSelectionIsQueuedWhilePreviousSelectionIsSyncing() async throws {
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

        let executor = BlockingRemoteSyncExecutor()
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: executor
        )
        let initialSync = Task {
            await worker.activate(for: userID)
        }
        await executor.waitUntilFirstExecutionStarts()

        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: secondProgram.id
        )
        let repeatedRequest = Task {
            await worker.requestSync()
        }

        await executor.releaseFirstExecution()
        await initialSync.value
        await repeatedRequest.value

        let selectedPrograms = await executor.executedProgramIDs()
        let localUser = try #require(
            try await factory.userRepository.user(id: userID)
        )

        #expect(selectedPrograms == [firstProgram.id, secondProgram.id])
        #expect(localUser.selectedProgramId == secondProgram.id)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 0)
    }

    @Test
    func failedOperationReturnsToPendingWithBackoff() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let userID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        _ = try await factory.userRepository.currentUser()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: nil
        )
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: FailingRemoteSyncExecutor()
        )

        await worker.activate(for: userID)

        let operation = try #require(
            try stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>()).first
        )
        #expect(operation.statusRawValue == SyncOperationStatus.pending.rawValue)
        #expect(operation.attemptCount == 1)
        #expect(operation.nextAttemptAt != nil)

        await worker.deactivate()
    }

    @Test
    func invalidOperationIsMarkedAsPermanentlyFailed() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let userID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        _ = try await factory.userRepository.currentUser()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: nil
        )
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: InvalidRemoteSyncExecutor()
        )

        await worker.activate(for: userID)

        let operation = try #require(
            try stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>()).first
        )
        #expect(operation.statusRawValue == SyncOperationStatus.failed.rawValue)
        #expect(operation.attemptCount == 1)
        #expect(operation.nextAttemptAt == nil)
    }
}

private actor BlockingRemoteSyncExecutor: RemoteSyncExecuting {
    private var executedIDs: [UUID?] = []
    private var firstExecutionStarted = false
    private var firstExecutionWaiter: CheckedContinuation<Void, Never>?
    private var firstExecutionRelease: CheckedContinuation<Void, Never>?

    func execute(_ operation: SyncOperation) async throws -> SyncExecutionResult {
        let payload = try JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: operation.payload
        )
        executedIDs.append(payload.selectedProgramID)

        if executedIDs.count == 1 {
            firstExecutionStarted = true
            firstExecutionWaiter?.resume()
            firstExecutionWaiter = nil

            await withCheckedContinuation { continuation in
                firstExecutionRelease = continuation
            }
        }

        return .userProfile(
            User(
                id: operation.aggregateID,
                selectedProgramId: payload.selectedProgramID,
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date()
            )
        )
    }

    func waitUntilFirstExecutionStarts() async {
        guard !firstExecutionStarted else { return }

        await withCheckedContinuation { continuation in
            firstExecutionWaiter = continuation
        }
    }

    func releaseFirstExecution() {
        firstExecutionRelease?.resume()
        firstExecutionRelease = nil
    }

    func executedProgramIDs() -> [UUID?] {
        executedIDs
    }
}

private struct FailingRemoteSyncExecutor: RemoteSyncExecuting {
    func execute(_: SyncOperation) throws -> SyncExecutionResult {
        throw SyncWorkerTestError.networkUnavailable
    }
}

private struct InvalidRemoteSyncExecutor: RemoteSyncExecuting {
    func execute(_: SyncOperation) throws -> SyncExecutionResult {
        throw SyncError.invalidPayload
    }
}

private enum SyncWorkerTestError: Error {
    case networkUnavailable
}
