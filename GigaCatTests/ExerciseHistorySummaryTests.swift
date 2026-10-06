import Foundation
import Testing
@testable import GigaCat

struct ExerciseHistorySummaryTests {
    @Test
    func selectsLastLogFromLatestCompletedSessionAndBestPerformance() throws {
        let olderSession = try makeCompletedSession(completedAt: 1_000)
        let latestSession = try makeCompletedSession(completedAt: 2_000)
        let activeSession = try WorkoutSession(
            userId: UUID(),
            workoutDayId: UUID(),
            startedAt: Date(timeIntervalSince1970: 3_000)
        )
        let olderBest = try makeLog(
            sessionID: olderSession.id,
            weight: 100,
            reps: 3,
            setNumber: 1,
            performedAt: 900
        )
        let bestWithMoreReps = try makeLog(
            sessionID: olderSession.id,
            weight: 100,
            reps: 5,
            setNumber: 2,
            performedAt: 950
        )
        let latestSessionFirst = try makeLog(
            sessionID: latestSession.id,
            weight: 80,
            reps: 8,
            setNumber: 1,
            performedAt: 1_800
        )
        let expectedPrevious = try makeLog(
            sessionID: latestSession.id,
            weight: 75,
            reps: 10,
            setNumber: 2,
            performedAt: 1_900
        )
        let activeHeavyLog = try makeLog(
            sessionID: activeSession.id,
            weight: 150,
            reps: 1,
            setNumber: 1,
            performedAt: 3_100
        )

        let summary = ExerciseHistorySummary(
            completedSessions: [olderSession, latestSession, activeSession],
            logs: [
                olderBest,
                bestWithMoreReps,
                latestSessionFirst,
                expectedPrevious,
                activeHeavyLog
            ]
        )

        #expect(summary.previousLog == expectedPrevious)
        #expect(summary.bestLog == bestWithMoreReps)
    }

    @Test
    func equalWeightAndRepsUseMostRecentLog() throws {
        let session = try makeCompletedSession(completedAt: 2_000)
        let older = try makeLog(
            sessionID: session.id,
            weight: 80,
            reps: 8,
            setNumber: 1,
            performedAt: 1_800
        )
        let newer = try makeLog(
            sessionID: session.id,
            weight: 80,
            reps: 8,
            setNumber: 2,
            performedAt: 1_900
        )

        let summary = ExerciseHistorySummary(
            completedSessions: [session],
            logs: [older, newer]
        )

        #expect(summary.bestLog == newer)
    }

    @Test
    func emptyCompletedHistoryProducesEmptySummary() {
        let summary = ExerciseHistorySummary(completedSessions: [], logs: [])

        #expect(summary.previousLog == nil)
        #expect(summary.bestLog == nil)
    }
}

private extension ExerciseHistorySummaryTests {
    func makeCompletedSession(completedAt: TimeInterval) throws -> WorkoutSession {
        let completedAt = Date(timeIntervalSince1970: completedAt)
        return try WorkoutSession(
            userId: UUID(),
            workoutDayId: UUID(),
            status: .completed,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt
        )
    }

    func makeLog(
        sessionID: UUID,
        weight: Double,
        reps: Int,
        setNumber: Int,
        performedAt: TimeInterval
    ) throws -> ExerciseLog {
        try ExerciseLog(
            sessionId: sessionID,
            workoutDayExerciseId: UUID(),
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            performedAt: Date(timeIntervalSince1970: performedAt)
        )
    }
}
