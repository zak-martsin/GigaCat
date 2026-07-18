import Foundation

extension MockSeedData {
    static func makeSessions(_ context: MockSeedContext) -> [WorkoutSession] {
        compact([
            try? WorkoutSession(
                id: context.activeSessionID,
                userId: context.currentUserID,
                workoutDayId: context.pushDayID,
                startedAt: context.activeSessionStartedAt
            ),
            try? WorkoutSession(
                id: context.completedStrengthSessionID,
                userId: context.currentUserID,
                workoutDayId: context.squatDayID,
                status: .completed,
                startedAt: context.completedStrengthStartedAt,
                completedAt: context.completedStrengthEndedAt
            ),
            try? WorkoutSession(
                id: context.secondUserSessionID,
                userId: context.secondUserID,
                workoutDayId: context.upperStrengthDayID,
                status: .completed,
                startedAt: context.secondUserSessionStartedAt,
                completedAt: context.secondUserSessionEndedAt
            )
        ])
    }

    static func makeExerciseLogs(_ context: MockSeedContext) -> [ExerciseLog] {
        compact([
            try? ExerciseLog(
                id: uuid("cccccccc-cccc-cccc-cccc-cccccccccccc"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("88888888-8888-8888-8888-888888888888"),
                weight: 60,
                reps: 8,
                setNumber: 1,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(300)
            ),
            try? ExerciseLog(
                id: uuid("dddddddd-dddd-dddd-dddd-dddddddddddd"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("88888888-8888-8888-8888-888888888888"),
                weight: 60,
                reps: 7,
                setNumber: 2,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(660)
            ),
            try? ExerciseLog(
                id: uuid("dededede-dede-dede-dede-dededededede"),
                sessionId: context.activeSessionID,
                workoutDayExerciseId: uuid("99999999-9999-9999-9999-999999999999"),
                weight: 35,
                reps: 10,
                setNumber: 1,
                performedAt: context.activeSessionStartedAt.addingTimeInterval(1_020)
            ),
            try? ExerciseLog(
                id: uuid("dfdfdfdf-dfdf-dfdf-dfdf-dfdfdfdfdfdf"),
                sessionId: context.completedStrengthSessionID,
                workoutDayExerciseId: uuid("abababab-abab-abab-abab-abababababab"),
                weight: 90,
                reps: 5,
                setNumber: 1,
                performedAt: context.completedStrengthStartedAt.addingTimeInterval(420)
            ),
            try? ExerciseLog(
                id: uuid("e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0"),
                sessionId: context.completedStrengthSessionID,
                workoutDayExerciseId: uuid("abababab-abab-abab-abab-abababababab"),
                weight: 92.5,
                reps: 5,
                setNumber: 2,
                performedAt: context.completedStrengthStartedAt.addingTimeInterval(900)
            ),
            try? ExerciseLog(
                id: uuid("e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1"),
                sessionId: context.secondUserSessionID,
                workoutDayExerciseId: uuid("adadadad-adad-adad-adad-adadadadadad"),
                weight: 72.5,
                reps: 6,
                setNumber: 1,
                performedAt: context.secondUserSessionStartedAt.addingTimeInterval(360)
            ),
            try? ExerciseLog(
                id: uuid("e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2"),
                sessionId: context.secondUserSessionID,
                workoutDayExerciseId: uuid("aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae"),
                weight: 62.5,
                reps: 8,
                setNumber: 1,
                performedAt: context.secondUserSessionStartedAt.addingTimeInterval(780)
            )
        ])
    }
}
