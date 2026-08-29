import Foundation

/// Domain values required to hydrate an empty local workout catalog.
struct WorkoutCatalogSeed {
    let programs: [WorkoutProgram]
    let workoutDays: [WorkoutDay]
    let dayExercises: [WorkoutDayExercise]
    let exercises: [Exercise]
}
