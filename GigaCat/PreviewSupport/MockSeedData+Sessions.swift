import Foundation

extension MockSeedData {
    static func makeSessions(_ context: MockSeedContext) throws -> [WorkoutSession] {
        try [
            WorkoutSession(
                id: context.activeSessionID,
                userId: context.currentUserID,
                workoutDayId: context.activeWorkoutDayID,
                startedAt: context.activeSessionStartedAt
            ),
            WorkoutSession(
                id: context.completedSessionID,
                userId: context.currentUserID,
                workoutDayId: context.completedWorkoutDayID,
                status: .completed,
                startedAt: context.completedSessionStartedAt,
                completedAt: context.completedSessionEndedAt
            ),
            WorkoutSession(
                id: context.secondUserSessionID,
                userId: context.secondUserID,
                workoutDayId: context.secondUserWorkoutDayID,
                status: .completed,
                startedAt: context.secondUserSessionStartedAt,
                completedAt: context.secondUserSessionEndedAt
            )
        ]
    }

    static func makeExerciseLogs(_ context: MockSeedContext) throws -> [ExerciseLog] {
        try makeCurrentUserLogs(context) + makeSecondUserLogs(context)
    }

    private static func makeCurrentUserLogs(
        _ context: MockSeedContext
    ) throws -> [ExerciseLog] {
        try [
            ExerciseLog(
                id: uuid("cccccccc-cccc-cccc-cccc-cccccccccccc"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000001"),
                weight: 60,
                reps: 8,
                setNumber: 1,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(300)
            ),
            ExerciseLog(
                id: uuid("dddddddd-dddd-dddd-dddd-dddddddddddd"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000001"),
                weight: 60,
                reps: 7,
                setNumber: 2,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(660)
            ),
            ExerciseLog(
                id: uuid("dededede-dede-dede-dede-dededededede"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000002"),
                weight: 35,
                reps: 10,
                setNumber: 1,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(1_020)
            ),
            ExerciseLog(
                id: uuid("dfdfdfdf-dfdf-dfdf-dfdf-dfdfdfdfdfdf"),
                sessionId: context.completedSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000020"),
                weight: 90,
                reps: 5,
                setNumber: 1,
                performedAt: context.completedSessionStartedAt.addingTimeInterval(420)
            ),
            ExerciseLog(
                id: uuid("e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0"),
                sessionId: context.completedSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000020"),
                weight: 92.5,
                reps: 5,
                setNumber: 2,
                performedAt: context.completedSessionStartedAt.addingTimeInterval(900)
            )
        ]
    }

    private static func makeSecondUserLogs(
        _ context: MockSeedContext
    ) throws -> [ExerciseLog] {
        try [
            ExerciseLog(
                id: uuid("e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1"),
                sessionId: context.secondUserSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000029"),
                weight: 72.5,
                reps: 6,
                setNumber: 1,
                performedAt: context.secondUserSessionStartedAt.addingTimeInterval(360)
            ),
            ExerciseLog(
                id: uuid("e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2"),
                sessionId: context.secondUserSessionID,
                workoutDayExerciseId: uuid("40000000-0000-0000-0000-000000000030"),
                weight: 62.5,
                reps: 8,
                setNumber: 1,
                performedAt: context.secondUserSessionStartedAt.addingTimeInterval(780)
            )
        ]
    }
}
