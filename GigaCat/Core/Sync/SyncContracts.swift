import Foundation

protocol RemoteSyncExecuting: Sendable {
    func execute(_ operation: SyncOperation) async throws -> SyncExecutionResult
}

/// Persists and claims outgoing changes without exposing SwiftData to the worker.
@MainActor
protocol SyncOutboxRepository: AnyObject {
    func recoverInterruptedOperations(for userID: UUID) throws
    func claimNextReadyOperation(for userID: UUID, now: Date) throws -> SyncOperation?
    func complete(_ operation: SyncOperation, with result: SyncExecutionResult) throws
    func fail(_ operation: SyncOperation, message: String, retryAt: Date) throws
    func pauseForAuthentication(_ operation: SyncOperation, message: String) throws
    func failPermanently(_ operation: SyncOperation, message: String) throws
    func hasReadyOperations(for userID: UUID, now: Date) throws -> Bool
    func nextRetryDate(for userID: UUID, after date: Date) throws -> Date?
    /// Reports profile operations that may still reach the server; terminal failures are excluded.
    func hasUnfinishedProfileOperation(for userID: UUID) throws -> Bool
    /// Blocks automatic remote pulls until a queued or failed local intent is resolved.
    func hasUnresolvedProfileOperation(for userID: UUID) throws -> Bool
    func profileSyncStatus(for userID: UUID) throws -> ProfileSyncStatus
    func retryFailedProfileOperation(for userID: UUID) throws -> Bool
    func removeFailedProfileOperations(for userID: UUID) throws -> Bool
}

/// Receives lifecycle and mutation signals without exposing synchronization details to features.
@MainActor
protocol SyncCoordinating: AnyObject {
    func activate(for userID: UUID) async
    func deactivate() async
    /// Returns after the worker has finished the pass requested by this caller.
    func requestSync() async
}
