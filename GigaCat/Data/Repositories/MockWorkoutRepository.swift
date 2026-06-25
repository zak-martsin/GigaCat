import Foundation

/// In-memory workout repository for session lifecycle and set logging flows.
struct MockWorkoutRepository: WorkoutRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func activeSession(for userId: UUID) async throws -> WorkoutSession? {
        await store.activeSession(for: userId)
    }

    func startSession(userId: UUID, workoutDayId: UUID, startedAt: Date) async throws -> WorkoutSession {
        try await store.startSession(userId: userId, workoutDayId: workoutDayId, startedAt: startedAt)
    }

    func completeSession(sessionId: UUID, completedAt: Date) async throws -> WorkoutSession {
        try await store.completeSession(sessionId: sessionId, completedAt: completedAt)
    }

    func saveExerciseLog(_ log: ExerciseLog) async throws -> ExerciseLog {
        try await store.saveExerciseLog(log)
    }

    func fetchSessions(for userId: UUID) async throws -> [WorkoutSession] {
        await store.sessions(for: userId)
    }

    func fetchExerciseLogs(sessionId: UUID) async throws -> [ExerciseLog] {
        await store.exerciseLogs(sessionId: sessionId)
    }

    func fetchRecentExerciseLogs(
        userId: UUID,
        exerciseId: UUID,
        limit: Int
    ) async throws -> [ExerciseLog] {
        await store.recentExerciseLogs(userId: userId, exerciseId: exerciseId, limit: limit)
    }
}
