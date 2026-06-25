import Foundation

/// Read-only access to predefined programs, workout days, and exercise definitions.
protocol WorkoutProgramRepository: Sendable {
    func fetchPrograms() async throws -> [WorkoutProgram]
    func fetchProgram(id: UUID) async throws -> WorkoutProgram?
    func fetchWorkoutDays(programId: UUID) async throws -> [WorkoutDay]
    func fetchWorkoutDayExercises(workoutDayId: UUID) async throws -> [WorkoutDayExercise]
    func fetchExercise(id: UUID) async throws -> Exercise?
}
