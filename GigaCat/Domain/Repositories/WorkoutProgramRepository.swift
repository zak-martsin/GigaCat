import Foundation

/// Read-only access to predefined programs, workout days, and exercise definitions.
protocol WorkoutProgramRepository {
    func fetchProgram(id: UUID) async throws -> WorkoutProgram?
    func fetchWorkoutDays(programId: UUID) async throws -> [WorkoutDay]
    func fetchWorkoutDaysForHistory(programId: UUID) async throws -> [WorkoutDay]
    func fetchWorkoutDay(id: UUID) async throws -> WorkoutDay?
    func fetchWorkoutDayExercises(workoutDayId: UUID) async throws -> [WorkoutDayExercise]
    func fetchWorkoutDayExercisesForHistory(
        workoutDayId: UUID
    ) async throws -> [WorkoutDayExercise]
    func fetchExercise(id: UUID) async throws -> Exercise?
}

extension WorkoutProgramRepository {
    /// Mocks can share the active lookup when they do not model catalog deactivation.
    func fetchWorkoutDaysForHistory(programId: UUID) async throws -> [WorkoutDay] {
        try await fetchWorkoutDays(programId: programId)
    }

    /// Mocks can share the active lookup when they do not model catalog deactivation.
    func fetchWorkoutDayExercisesForHistory(
        workoutDayId: UUID
    ) async throws -> [WorkoutDayExercise] {
        try await fetchWorkoutDayExercises(workoutDayId: workoutDayId)
    }
}
