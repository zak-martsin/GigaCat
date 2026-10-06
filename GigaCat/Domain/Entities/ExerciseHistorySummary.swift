import Foundation

/// Previous and best completed-session performances for one reusable exercise.
struct ExerciseHistorySummary: Equatable, Sendable {
    let previousLog: ExerciseLog?
    let bestLog: ExerciseLog?

    init(
        completedSessions: [WorkoutSession],
        logs: [ExerciseLog]
    ) {
        let completedSessionsByID = Dictionary(
            uniqueKeysWithValues: completedSessions
                .filter { $0.status == .completed }
                .map { ($0.id, $0) }
        )
        let completedLogs = logs.filter {
            completedSessionsByID[$0.sessionId] != nil
        }
        let previousSession = completedSessionsByID.values
            .filter { session in
                completedLogs.contains { $0.sessionId == session.id }
            }
            .max(by: Self.isSessionOlder)

        previousLog = previousSession.flatMap { session in
            completedLogs
                .filter { $0.sessionId == session.id }
                .max(by: Self.isLogOlder)
        }
        bestLog = completedLogs.max(by: Self.isPerformanceWorse)
    }

    private static func isSessionOlder(
        _ lhs: WorkoutSession,
        _ rhs: WorkoutSession
    ) -> Bool {
        let lhsCompletedAt = lhs.completedAt ?? lhs.startedAt
        let rhsCompletedAt = rhs.completedAt ?? rhs.startedAt

        if lhsCompletedAt != rhsCompletedAt {
            return lhsCompletedAt < rhsCompletedAt
        }

        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt < rhs.startedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func isLogOlder(
        _ lhs: ExerciseLog,
        _ rhs: ExerciseLog
    ) -> Bool {
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }

        if lhs.setNumber != rhs.setNumber {
            return lhs.setNumber < rhs.setNumber
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func isPerformanceWorse(
        _ lhs: ExerciseLog,
        _ rhs: ExerciseLog
    ) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight < rhs.weight
        }

        if lhs.reps != rhs.reps {
            return lhs.reps < rhs.reps
        }

        return isLogOlder(lhs, rhs)
    }
}
