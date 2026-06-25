import Foundation

/// Lifecycle state of a workout session.
enum WorkoutSessionStatus: String, Codable, Sendable {
    case inProgress
    case completed
    case needReview
}
