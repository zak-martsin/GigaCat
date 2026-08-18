import Foundation

/// Serially drains the persistent outbox and schedules in-memory retries.
actor SyncWorker {
    private let outboxRepository: any SyncOutboxRepository
    private let remoteExecutor: any RemoteSyncExecuting

    private var activeUserID: UUID?
    private var isRunning = false
    private var needsAnotherPass = false
    private var retryTask: Task<Void, Never>?

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

        do {
            try await outboxRepository.recoverInterruptedOperations(for: userID)
        } catch {
            return
        }

        await requestSync()
    }

    func deactivate() {
        activeUserID = nil
        needsAnotherPass = false
        retryTask?.cancel()
        retryTask = nil
    }

    func requestSync() async {
        guard let userID = activeUserID else { return }

        if isRunning {
            needsAnotherPass = true
            return
        }

        isRunning = true

        while true {
            needsAnotherPass = false
            await drainReadyOperations(for: userID)

            guard activeUserID == userID else { break }

            let hasReadyOperations = await hasReadyOperations(for: userID)
            guard needsAnotherPass || hasReadyOperations else { break }
        }

        isRunning = false

        if let activeUserID,
           activeUserID != userID {
            await requestSync()
            return
        }

        await scheduleRetryIfNeeded(for: userID)
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
            } catch let syncError as SyncError {
                guard activeUserID == userID else { return }
                try? await outboxRepository.failPermanently(
                    operation,
                    message: syncError.localizedDescription
                )
            } catch {
                guard activeUserID == userID else { return }
                let retryAt = Date().addingTimeInterval(
                    retryDelay(after: operation.attemptCount)
                )
                try? await outboxRepository.fail(
                    operation,
                    message: error.localizedDescription,
                    retryAt: retryAt
                )
            }
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
}
