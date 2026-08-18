import Foundation

enum SyncAggregateType: String, Codable, Sendable {
    case userProfile
}

enum SyncMutation: String, Codable, Sendable {
    case update
}

enum SyncOperationStatus: String, Codable, Sendable {
    case pending
    case syncing
    case failed
}

/// Immutable snapshot of one local change that still needs a remote acknowledgement.
struct SyncOperation: Identifiable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let aggregateType: SyncAggregateType
    let aggregateID: UUID
    let mutation: SyncMutation
    let payload: Data
    let revision: Int
    let status: SyncOperationStatus
    let createdAt: Date
    let attemptCount: Int
    let nextAttemptAt: Date?
}

struct UserProfileSyncPayload: Codable, Equatable, Sendable {
    let selectedProgramID: UUID?
}

enum SyncExecutionResult: Equatable, Sendable {
    case userProfile(User)
}

enum SyncError: LocalizedError {
    case invalidStoredOperation
    case invalidPayload
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .invalidStoredOperation:
            "A saved synchronization operation is invalid."
        case .invalidPayload:
            "A synchronization payload could not be decoded."
        case .unsupportedOperation:
            "This synchronization operation is not supported."
        }
    }
}
