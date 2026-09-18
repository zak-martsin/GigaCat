import Foundation

/// Converts app events into ordered requests for the single sync worker.
@MainActor
final class SyncCoordinator: SyncCoordinating {
    private let worker: SyncWorker

    init(worker: SyncWorker) {
        self.worker = worker
    }

    func activate(for userID: UUID) async {
        await worker.activate(for: userID)
    }

    func deactivate() async {
        await worker.deactivate()
    }

    func requestSync() async {
        await worker.requestSync()
    }
}
