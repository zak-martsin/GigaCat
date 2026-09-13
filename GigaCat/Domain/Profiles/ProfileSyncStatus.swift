import Foundation

/// Feature-facing profile state that does not expose outbox storage details.
enum ProfileSyncStatus: Equatable, Sendable {
    case synchronized
    case waiting
    case failed(message: String)
}
