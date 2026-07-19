import Foundation

/// Repository-backed workout data resolved for the first presentation of the Workout screen.
struct WorkoutContext: Equatable, Sendable {
    let program: WorkoutProgram
    let days: [WorkoutDay]
    let initialDayID: UUID
    let activeSession: WorkoutSession?
}
