import Foundation

/// Serially drains the persistent outbox and schedules in-memory retries.
actor SyncWorker {
    private let outboxRepository: any SyncOutboxRepository
    private let remoteExecutor: any RemoteSyncExecuting

    private var activeUserID: UUID?
    private var isRunning = false
    private var isPausedForAuthentication = false
    private var needsAnotherPass = false
    private var retryTask: Task<Void, Never>?
    private var runCompletionWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        outboxRepository: any SyncOutboxRepository,
        remoteExecutor: any RemoteSyncExecuting
    ) {
        self.outboxRepository = outboxRepository
        self.remoteExecutor = remoteExecutor
    }

    func activate(for userID: UUID) async {
        retryTask?.cancel()
        activeUserID = userID
        isPausedForAuthentication = false

        do {
            try await outboxRepository.recoverInterruptedOperations(for: userID)
        } catch {
            return
        }

        await requestSync()
    }

    /// Stops accepting work for the active account and waits for its current pass to unwind.
    func deactivate() async {
        activeUserID = nil
        isPausedForAuthentication = false
        needsAnotherPass = false
        retryTask?.cancel()
        retryTask = nil

        if isRunning {
            await waitForCurrentRun()
        }
    }

    /// Finishes only after the run containing this request has drained all ready work.
    func requestSync() async {
        guard activeUserID != nil, !isPausedForAuthentication else { return }

        if isRunning {
            needsAnotherPass = true
            await waitForCurrentRun()
            return
        }

        isRunning = true
        await runUntilIdle()
        isRunning = false
        resumeRunCompletionWaiters()
    }

    private func runUntilIdle() async {
        while let userID = activeUserID {
            needsAnotherPass = false
            await drainReadyOperations(for: userID)

            guard activeUserID == userID else { continue }
            guard !isPausedForAuthentication else { return }

            let hasReadyOperations = await hasReadyOperations(for: userID)
            guard activeUserID == userID else { continue }
            if needsAnotherPass || hasReadyOperations {
                continue
            }

            await scheduleRetryIfNeeded(for: userID)
            guard activeUserID == userID else { continue }
            guard needsAnotherPass else { return }
        }
    }

    private func drainReadyOperations(for userID: UUID) async {
        while activeUserID == userID {
            let operation: SyncOperation

            do {
                guard let claimedOperation = try await outboxRepository
                    .claimNextReadyOperation(for: userID, now: Date()) else {
                    return
                }
                operation = claimedOperation
            } catch {
                return
            }

            do {
                let result = try await remoteExecutor.execute(operation)
                guard activeUserID == userID else { return }
                try await outboxRepository.complete(operation, with: result)
            } catch {
                guard activeUserID == userID else { return }
                guard await handleFailure(error, for: operation) else { return }
            }
        }
    }

    private func handleFailure(
        _ error: any Error,
        for operation: SyncOperation
    ) async -> Bool {
        switch failureDisposition(for: error) {
        case .retry(let message):
            let retryAt = Date().addingTimeInterval(
                retryDelay(after: operation.attemptCount)
            )
            try? await outboxRepository.fail(
                operation,
                message: message,
                retryAt: retryAt
            )
            return true
        case .pauseForAuthentication(let message):
            try? await outboxRepository.pauseForAuthentication(
                operation,
                message: message
            )
            isPausedForAuthentication = true
            retryTask?.cancel()
            retryTask = nil
            return false
        case .failPermanently(let message):
            try? await outboxRepository.failPermanently(
                operation,
                message: message
            )
            return true
        }
    }

    private func failureDisposition(
        for error: any Error
    ) -> OperationFailureDisposition {
        if let syncError = error as? SyncError {
            return .failPermanently(message: syncError.localizedDescription)
        }

        guard let executionError = error as? SyncExecutionError else {
            return .retry(message: error.localizedDescription)
        }

        switch executionError {
        case .transient(let message):
            return .retry(message: message)
        case .authenticationRequired(let message):
            return .pauseForAuthentication(message: message)
        case .permanent(let message):
            return .failPermanently(message: message)
        }
    }

    private func hasReadyOperations(for userID: UUID) async -> Bool {
        (try? await outboxRepository.hasReadyOperations(
            for: userID,
            now: Date()
        )) ?? false
    }

    private func scheduleRetryIfNeeded(for userID: UUID) async {
        retryTask?.cancel()

        guard activeUserID == userID,
              let retryDate = try? await outboxRepository.nextRetryDate(
                for: userID,
                after: Date()
              ) else {
            retryTask = nil
            return
        }

        let delay = max(0, retryDate.timeIntervalSinceNow)
        retryTask = Task(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.requestSync()
        }
    }

    private func retryDelay(after attemptCount: Int) -> TimeInterval {
        let exponent = min(max(attemptCount, 0), 6)
        return min(5 * pow(2, Double(exponent)), 300)
    }

    private func waitForCurrentRun() async {
        await withCheckedContinuation { continuation in
            runCompletionWaiters.append(continuation)
        }
    }

    private func resumeRunCompletionWaiters() {
        let waiters = runCompletionWaiters
        runCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private enum OperationFailureDisposition {
    case retry(message: String)
    case pauseForAuthentication(message: String)
    case failPermanently(message: String)
}
