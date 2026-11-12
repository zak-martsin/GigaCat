import Foundation

/// A session-owned recommendation, independent of visible rows and performed sets.
/// The program override is captured so later catalog edits cannot alter this session's prescription.
struct WorkoutExerciseTarget: Codable, Equatable, Sendable {
    let workoutDayExerciseID: UUID
    let targetSets: Int
    let programOverride: Int?
}
