import Foundation
@testable import GigaCat

struct ControlledWorkoutRepository: WorkoutRepository {
    enum Failure: Equatable, Sendable {
        case currentSessionLogs
        case latestExerciseLog
    }

    let base: WorkoutRepository
    let failure: Failure

    func activeSession(for userId: UUID) async throws -> WorkoutSession? {
        try await base.activeSession(for: userId)
    }

    func startSession(
        userId: UUID,
        workoutDayId: UUID,
        startedAt: Date
    ) async throws -> WorkoutSession {
        try await base.startSession(
            userId: userId,
            workoutDayId: workoutDayId,
            startedAt: startedAt
        )
    }

    func completeSession(
        sessionId: UUID,
        completedAt: Date
    ) async throws -> WorkoutSession {
        try await base.completeSession(
            sessionId: sessionId,
            completedAt: completedAt
        )
    }

    func deleteSession(sessionId: UUID) async throws {
        try await base.deleteSession(sessionId: sessionId)
    }

    func completeSessionAndSelectProgram(
        sessionId: UUID,
        completedAt: Date,
        userId: UUID,
        programId: UUID
    ) async throws -> User {
        try await base.completeSessionAndSelectProgram(
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
        try await base.deleteSessionAndSelectProgram(
            sessionId: sessionId,
            userId: userId,
            programId: programId
        )
    }

    func saveSet(_ input: WorkoutSetInput) async throws -> WorkoutSetSaveResult {
        try await base.saveSet(input)
    }

    func fetchSessions(for userId: UUID) async throws -> [WorkoutSession] {
        try await base.fetchSessions(for: userId)
    }

    func fetchExerciseLogs(sessionId: UUID) async throws -> [ExerciseLog] {
        guard failure != .currentSessionLogs else {
            throw RepositoryError.workoutSessionNotFound
        }

        return try await base.fetchExerciseLogs(sessionId: sessionId)
    }

    func fetchLatestExerciseLog(
        userId: UUID,
        exerciseId: UUID
    ) async throws -> ExerciseLog? {
        guard failure != .latestExerciseLog else {
            throw RepositoryError.exerciseNotFound
        }

        return try await base.fetchLatestExerciseLog(
            userId: userId,
            exerciseId: exerciseId
        )
    }
}
