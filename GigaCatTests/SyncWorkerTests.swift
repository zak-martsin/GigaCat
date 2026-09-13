import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct SyncWorkerTests {

    @Test
    func newerSelectionIsQueuedAndRepeatedRequestWaitsForCurrentRun() async throws {
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
        let requestProbe = SyncRequestProbe()
        let repeatedRequest = Task {
            await requestProbe.markStarted()
            await worker.requestSync()
            await requestProbe.markCompleted()
        }

        await requestProbe.waitUntilStarted()
        try await Task.sleep(for: .milliseconds(100))
        #expect(await !requestProbe.isCompleted)

        await executor.releaseFirstExecution()
        await initialSync.value
        await repeatedRequest.value

        #expect(await requestProbe.isCompleted)

        let selectedPrograms = await executor.executedProgramIDs()
        let localUser = try #require(
            try await factory.userRepository.user(id: userID)
        )

        #expect(selectedPrograms == [firstProgram.id, secondProgram.id])
        #expect(localUser.selectedProgramId == secondProgram.id)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 0)
    }

    @Test
    func deactivateWaitsForInFlightPassToStop() async throws {
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
        let executor = BlockingRemoteSyncExecutor()
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: executor
        )
        let activePass = Task {
            await worker.activate(for: userID)
        }
        await executor.waitUntilFirstExecutionStarts()

        let deactivationProbe = SyncRequestProbe()
        let deactivation = Task {
            await deactivationProbe.markStarted()
            await worker.deactivate()
            await deactivationProbe.markCompleted()
        }

        await deactivationProbe.waitUntilStarted()
        try await Task.sleep(for: .milliseconds(100))
        #expect(await !deactivationProbe.isCompleted)

        await executor.releaseFirstExecution()
        await activePass.value
        await deactivation.value

        #expect(await deactivationProbe.isCompleted)
        #expect(await executor.executedProgramIDs() == [nil])
    }

    @Test
    func activatingUserClaimsOnlyThatUsersOperations() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let firstUserID = UUID()
        let secondUserID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: firstUserID)
        )
        try await factory.userRepository.save(User(id: firstUserID))
        try await factory.userRepository.save(User(id: secondUserID))
        _ = try await factory.userRepository.updateSelectedProgram(
            for: firstUserID,
            programId: nil
        )
        _ = try await factory.userRepository.updateSelectedProgram(
            for: secondUserID,
            programId: nil
        )
        let executor = UserRecordingRemoteSyncExecutor()
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: executor
        )

        await worker.activate(for: secondUserID)

        #expect(await executor.executedUserIDs() == [secondUserID])
        #expect(
            try factory.syncOutboxRepository.operationCount(for: firstUserID)
                == 1
        )
        #expect(
            try factory.syncOutboxRepository.operationCount(for: secondUserID)
                == 0
        )
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
        #expect(
            try !factory.syncOutboxRepository
                .hasUnfinishedProfileOperation(for: userID)
        )
    }

    @Test
    func authenticationFailurePausesUntilWorkerIsActivatedAgain() async throws {
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
        let executor = AuthRecoveringSyncExecutor()
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: executor
        )

        await worker.activate(for: userID)
        await worker.requestSync()

        #expect(await executor.executionCount == 1)
        let pausedOperation = try #require(
            try stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>()).first
        )
        #expect(pausedOperation.statusRawValue == SyncOperationStatus.pending.rawValue)
        #expect(pausedOperation.nextAttemptAt == nil)

        await worker.activate(for: userID)

        #expect(await executor.executionCount == 2)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 0)
    }

    @Test
    func successfulPushAppliesCanonicalServerProfile() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let userID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        let selectedProgram = try WorkoutProgram(
            title: "Selected",
            description: "Selected"
        )
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(selectedProgram))
        _ = try await factory.userRepository.currentUser()
        try stack.mainContext.save()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: userID,
            programId: selectedProgram.id
        )
        let canonicalProfile = User(
            id: userID,
            selectedProgramId: nil,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let worker = SyncWorker(
            outboxRepository: factory.syncOutboxRepository,
            remoteExecutor: CanonicalProfileRemoteSyncExecutor(
                profile: canonicalProfile
            )
        )

        await worker.activate(for: userID)

        let localProfile = try #require(
            try await factory.userRepository.user(id: userID)
        )
        #expect(localProfile.selectedProgramId == canonicalProfile.selectedProgramId)
        #expect(localProfile.createdAt == canonicalProfile.createdAt)
        #expect(localProfile.updatedAt == canonicalProfile.updatedAt)
        #expect(try factory.syncOutboxRepository.operationCount(for: userID) == 0)
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

private actor SyncRequestProbe {
    private var started = false
    private var completed = false
    private var startWaiter: CheckedContinuation<Void, Never>?

    var isCompleted: Bool {
        completed
    }

    func markStarted() {
        started = true
        startWaiter?.resume()
        startWaiter = nil
    }

    func waitUntilStarted() async {
        guard !started else { return }

        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func markCompleted() {
        completed = true
    }
}

private struct FailingRemoteSyncExecutor: RemoteSyncExecuting {
    func execute(_: SyncOperation) throws -> SyncExecutionResult {
        throw SyncExecutionError.transient(message: "Network unavailable")
    }
}

private actor AuthRecoveringSyncExecutor: RemoteSyncExecuting {
    private(set) var executionCount = 0

    func execute(_ operation: SyncOperation) throws -> SyncExecutionResult {
        executionCount += 1
        guard executionCount > 1 else {
            throw SyncExecutionError.authenticationRequired(message: "Session expired")
        }

        let payload = try JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: operation.payload
        )
        return .userProfile(
            User(
                id: operation.userID,
                selectedProgramId: payload.selectedProgramID
            )
        )
    }
}

private struct InvalidRemoteSyncExecutor: RemoteSyncExecuting {
    func execute(_: SyncOperation) throws -> SyncExecutionResult {
        throw SyncError.invalidPayload
    }
}

private struct CanonicalProfileRemoteSyncExecutor: RemoteSyncExecuting {
    let profile: User

    func execute(_: SyncOperation) -> SyncExecutionResult {
        .userProfile(profile)
    }
}

private actor UserRecordingRemoteSyncExecutor: RemoteSyncExecuting {
    private var userIDs: [UUID] = []

    func execute(_ operation: SyncOperation) throws -> SyncExecutionResult {
        let payload = try JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: operation.payload
        )
        userIDs.append(operation.userID)
        return .userProfile(
            User(
                id: operation.userID,
                selectedProgramId: payload.selectedProgramID
            )
        )
    }

    func executedUserIDs() -> [UUID] {
        userIDs
    }
}
