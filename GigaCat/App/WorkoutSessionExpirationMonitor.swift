import Foundation

/// Keeps one best-effort expiration timer while the application is active.
@MainActor
final class WorkoutSessionExpirationMonitor {
    typealias SleepUntil = @Sendable (Date) async throws -> Void

    private let service: any WorkoutSessionExpirationServicing
    private let now: @MainActor () -> Date
    private let sleepUntil: SleepUntil
    private let onSessionExpired: @MainActor () async -> Void
    private var expirationTask: Task<Void, Never>?
    private var observedUserID: UUID?
    private var refreshGeneration = 0

    init(
        service: any WorkoutSessionExpirationServicing,
        now: @escaping @MainActor () -> Date = Date.init,
        sleepUntil: @escaping SleepUntil = { date in
            try await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
        },
        onSessionExpired: @escaping @MainActor () async -> Void
    ) {
        self.service = service
        self.now = now
        self.sleepUntil = sleepUntil
        self.onSessionExpired = onSessionExpired
    }

    /// Reconciles persisted state and replaces any timer derived from older activity.
    @discardableResult
    func refresh(for userID: UUID) async -> Bool {
        observedUserID = userID
        refreshGeneration += 1
        let generation = refreshGeneration

        expirationTask?.cancel()
        expirationTask = nil

        let result: WorkoutSessionExpirationResult
        do {
            result = try await service.reconcile(for: userID, now: now())
        } catch {
            return false
        }

        guard generation == refreshGeneration, observedUserID == userID else {
            return false
        }

        switch result {
        case .noActiveSession:
            return false
        case let .scheduled(expirationDate):
            scheduleRefresh(at: expirationDate, for: userID)
            return false
        case .completed:
            await onSessionExpired()
            return true
        }
    }

    func refresh() async {
        guard let observedUserID else { return }
        await refresh(for: observedUserID)
    }

    func stop() {
        refreshGeneration += 1
        observedUserID = nil
        expirationTask?.cancel()
        expirationTask = nil
    }

    private func scheduleRefresh(at date: Date, for userID: UUID) {
        let sleepUntil = sleepUntil
        expirationTask = Task { [weak self] in
            do {
                try await sleepUntil(date)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.refresh(for: userID)
        }
    }
}
