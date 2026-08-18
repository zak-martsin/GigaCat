import Foundation

/// Converts app events into low-priority requests for the single sync worker.
@MainActor
final class SyncCoordinator: SyncCoordinating {
    private let worker: SyncWorker

    init(worker: SyncWorker) {
        self.worker = worker
    }

    func activate(for userID: UUID) {
        Task(priority: .utility) {
            await worker.activate(for: userID)
        }
    }

    func deactivate() {
        Task(priority: .utility) {
            await worker.deactivate()
        }
    }

    func requestSync() {
        Task(priority: .utility) {
            await worker.requestSync()
        }
    }
}
