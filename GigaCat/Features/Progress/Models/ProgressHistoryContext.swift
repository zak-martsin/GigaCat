import Foundation

/// Repository-backed completed workout history prepared for Progress presentation.
struct ProgressHistoryContext: Equatable, Sendable {
    let userID: UUID
    let sessions: [ProgressSessionHistory]
}

/// A completed session paired with the workout metadata and performed exercises it references.
struct ProgressSessionHistory: Equatable, Sendable {
    let session: WorkoutSession
    let workoutDay: WorkoutDay
    let programTitle: String
    let exercises: [ProgressExerciseHistory]
}

/// A planned exercise paired with its definition and performed sets for one session.
struct ProgressExerciseHistory: Equatable, Sendable {
    let dayExercise: WorkoutDayExercise
    let exercise: Exercise
    let logs: [ExerciseLog]
}
