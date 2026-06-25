import Foundation

/// Primary muscle group used to categorize reusable exercises.
enum ExerciseMuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case legs
    case glutes
    case core
    case fullBody
    case cardio
    case other
}
