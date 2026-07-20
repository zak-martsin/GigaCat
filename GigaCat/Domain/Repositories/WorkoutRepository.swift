import Foundation

/// Coordinates workout session lifecycle and persisted exercise logging.
protocol WorkoutRepository: Sendable {
    func activeSession(for userId: UUID) async throws -> WorkoutSession?
    func startSession(userId: UUID, workoutDayId: UUID, startedAt: Date) async throws -> WorkoutSession
    func completeSession(sessionId: UUID, completedAt: Date) async throws -> WorkoutSession
    func deleteSession(sessionId: UUID) async throws
    func completeSessionAndSelectProgram(
        sessionId: UUID,
        completedAt: Date,
        userId: UUID,
        programId: UUID
    ) async throws -> User
    func deleteSessionAndSelectProgram(
        sessionId: UUID,
        userId: UUID,
        programId: UUID
    ) async throws -> User
    func saveSet(_ input: WorkoutSetInput) async throws -> WorkoutSetSaveResult
    func fetchSessions(for userId: UUID) async throws -> [WorkoutSession]
    func fetchExerciseLogs(sessionId: UUID) async throws -> [ExerciseLog]
    func fetchRecentExerciseLogs(
        userId: UUID,
        exerciseId: UUID,
        limit: Int
    ) async throws -> [ExerciseLog]
}
