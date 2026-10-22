import Foundation

enum WorkoutSessionExpirationResult: Equatable, Sendable {
    case noActiveSession
    case scheduled(Date)
    case completed(WorkoutSession)
}

/// Reconciles the persisted active session with the expiration policy.
protocol WorkoutSessionExpirationServicing {
    func reconcile(
        for userID: UUID,
        now: Date
    ) async throws -> WorkoutSessionExpirationResult
}

struct WorkoutSessionExpirationService: WorkoutSessionExpirationServicing {
    private let workoutRepository: any WorkoutRepository
    private let policy: WorkoutSessionExpirationPolicy

    init(
        workoutRepository: any WorkoutRepository,
        policy: WorkoutSessionExpirationPolicy = WorkoutSessionExpirationPolicy()
    ) {
        self.workoutRepository = workoutRepository
        self.policy = policy
    }

    func reconcile(
        for userID: UUID,
        now: Date
    ) async throws -> WorkoutSessionExpirationResult {
        guard let session = try await workoutRepository.activeSession(for: userID) else {
            return .noActiveSession
        }

        let logs = try await workoutRepository.fetchExerciseLogs(sessionId: session.id)
        let expirationDate = policy.expirationDate(
            startedAt: session.startedAt,
            lastActivityAt: logs.map(\.performedAt).max()
        )

        guard now >= expirationDate else {
            return .scheduled(expirationDate)
        }

        let completedSession = try await workoutRepository.completeSession(
            sessionId: session.id,
            userId: userID,
            completedAt: expirationDate
        )
        return .completed(completedSession)
    }
}
