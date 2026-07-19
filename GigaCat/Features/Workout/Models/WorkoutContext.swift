import Foundation

/// Repository-backed workout data resolved for the first presentation of the Workout screen.
struct WorkoutContext: Equatable, Sendable {
    let program: WorkoutProgram
    let dayContents: [WorkoutDayContent]
    let initialDayID: UUID
    let activeSession: WorkoutSession?
}

/// A workout day paired with the exercise definitions and targets needed to present it.
struct WorkoutDayContent: Equatable, Sendable {
    let day: WorkoutDay
    let exercises: [WorkoutExerciseContent]
}

/// A reusable exercise paired with its planned targets for a specific workout day.
struct WorkoutExerciseContent: Equatable, Sendable {
    let dayExercise: WorkoutDayExercise
    let exercise: Exercise
}
