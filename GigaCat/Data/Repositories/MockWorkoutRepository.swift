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

    func deleteSession(sessionId: UUID) async throws {
        try await store.deleteSession(sessionId: sessionId)
    }

    func completeSessionAndSelectProgram(
        sessionId: UUID,
        completedAt: Date,
        userId: UUID,
        programId: UUID
    ) async throws -> User {
        try await store.completeSessionAndSelectProgram(
            sessionId: sessionId,
            completedAt: completedAt,
            userId: userId,
            programId: programId
        )
    }

    func deleteSessionAndSelectProgram(
        sessionId: UUID,
        userId: UUID,
        programId: UUID
    ) async throws -> User {
        try await store.deleteSessionAndSelectProgram(
            sessionId: sessionId,
            userId: userId,
            programId: programId
        )
    }

    func saveSet(_ input: WorkoutSetInput) async throws -> WorkoutSetSaveResult {
        try await store.saveSet(input)
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
