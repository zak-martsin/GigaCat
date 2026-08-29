import Foundation

/// Audience a workout program was designed for when that distinction matters.
enum WorkoutProgramAudience: String, Codable, CaseIterable, Sendable {
    case men
    case women
    case unisex
}
