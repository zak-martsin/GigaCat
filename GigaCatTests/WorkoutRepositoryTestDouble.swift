import Foundation
@testable import GigaCat

actor WorkoutRepositoryTestDouble: WorkoutRepository {
    enum Failure: Equatable, Sendable {
        case currentSessionLogs
        case latestExerciseLog
    }

    let base: WorkoutRepository
    let failure: Failure?
    private let blocksSave: Bool
    private var receivedSaveInputs: [WorkoutSetInput] = []
    private var saveStarted = false
    private var saveReleased = false
    private var saveStartedContinuation: CheckedContinuation<Void, Never>?
    private var saveContinuation: CheckedContinuation<Void, Never>?

    init(
        base: WorkoutRepository,
        failure: Failure? = nil,
        blocksSave: Bool = false
    ) {
        self.base = base
        self.failure = failure
        self.blocksSave = blocksSave
    }

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
        receivedSaveInputs.append(input)

        if blocksSave {
            saveStarted = true
            saveStartedContinuation?.resume()
            saveStartedContinuation = nil

            await withCheckedContinuation { continuation in
                if saveReleased {
                    continuation.resume()
                } else {
                    saveContinuation = continuation
                }
            }
        }

        return try await base.saveSet(input)
    }

    func waitUntilSaveStarts() async {
        guard !saveStarted else { return }

        await withCheckedContinuation { continuation in
            saveStartedContinuation = continuation
        }
    }

    func releaseSave() {
        saveReleased = true
        saveContinuation?.resume()
        saveContinuation = nil
    }

    func saveInputs() -> [WorkoutSetInput] {
        receivedSaveInputs
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
