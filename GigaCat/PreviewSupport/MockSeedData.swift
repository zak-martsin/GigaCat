import Foundation

/// Fixture builder for previews, tests, and early feature development before real persistence exists.
enum MockSeedData {
    /// Creates a coherent graph of users, programs, workout days, exercises, sessions, and logs.
    static func makeStore() -> MockDataStore {
        let currentUserID = uuid("11111111-1111-1111-1111-111111111111")
        let secondUserID = uuid("11111111-1111-1111-1111-222222222222")

        let upperBodyProgramID = uuid("22222222-2222-2222-2222-222222222222")
        let strengthProgramID = uuid("23232323-2323-2323-2323-232323232323")
        let conditioningProgramID = uuid("24242424-2424-2424-2424-242424242424")
        let mobilityProgramID = uuid("25252525-2525-2525-2525-252525252525")

        let pushDayID = uuid("33333333-3333-3333-3333-333333333333")
        let pullDayID = uuid("44444444-4444-4444-4444-444444444444")
        let armsDayID = uuid("43434343-4343-4343-4343-434343434343")
        let squatDayID = uuid("45454545-4545-4545-4545-454545454545")
        let upperStrengthDayID = uuid("46464646-4646-4646-4646-464646464646")
        let deadliftDayID = uuid("56565656-5656-5656-5656-565656565656")
        let sprintDayID = uuid("47474747-4747-4747-4747-474747474747")
        let conditioningDayID = uuid("48484848-4848-4848-4848-484848484848")
        let coreDayID = uuid("49494949-4949-4949-4949-494949494949")
        let flowDayID = uuid("50505050-5050-5050-5050-505050505050")
        let recoveryDayID = uuid("51515151-5151-5151-5151-515151515151")

        let benchExerciseID = uuid("55555555-5555-5555-5555-555555555555")
        let pressExerciseID = uuid("66666666-6666-6666-6666-666666666666")
        let rowExerciseID = uuid("77777777-7777-7777-7777-777777777777")
        let squatExerciseID = uuid("78787878-7878-7878-7878-787878787878")
        let deadliftExerciseID = uuid("79797979-7979-7979-7979-797979797979")
        let runExerciseID = uuid("7a7a7a7a-7a7a-7a7a-7a7a-7a7a7a7a7a7a")
        let lungeExerciseID = uuid("7b7b7b7b-7b7b-7b7b-7b7b-7b7b7b7b7b7b")
        let inclinePressExerciseID = uuid("7c7c7c7c-7c7c-7c7c-7c7c-7c7c7c7c7c7c")
        let pullUpExerciseID = uuid("7d7d7d7d-7d7d-7d7d-7d7d-7d7d7d7d7d7d")
        let lateralRaiseExerciseID = uuid("7e7e7e7e-7e7e-7e7e-7e7e-7e7e7e7e7e7e")
        let plankExerciseID = uuid("80808080-8080-8080-8080-808080808080")
        let burpeeExerciseID = uuid("81818181-8181-8181-8181-818181818181")
        let catCowExerciseID = uuid("82828282-8282-8282-8282-828282828282")
        let hipBridgeExerciseID = uuid("83838383-8383-8383-8383-838383838383")

        let activeSessionID = uuid("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        let completedStrengthSessionID = uuid("bcbcbcbc-bcbc-bcbc-bcbc-bcbcbcbcbcbc")
        let secondUserSessionID = uuid("bdbdbdbd-bdbd-bdbd-bdbd-bdbdbdbdbdbd")

        let now = Date()
        let createdAt = now.addingTimeInterval(-86_400 * 12)
        let activeSessionStartedAt = now.addingTimeInterval(-1_800)
        let completedStrengthStartedAt = now.addingTimeInterval(-86_400 * 2)
        let completedStrengthEndedAt = now.addingTimeInterval(-86_400 * 2 + 2_700)
        let secondUserSessionStartedAt = now.addingTimeInterval(-86_400 * 3)
        let secondUserSessionEndedAt = now.addingTimeInterval(-86_400 * 3 + 1_900)

        let currentUser = try? User(
            id: currentUserID,
            appleUserId: "mock-apple-user",
            selectedProgramId: upperBodyProgramID,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let secondUser = try? User(
            id: secondUserID,
            appleUserId: "mock-second-user",
            selectedProgramId: strengthProgramID,
            createdAt: createdAt.addingTimeInterval(600),
            updatedAt: createdAt.addingTimeInterval(600)
        )

        let upperBodyProgram = try? WorkoutProgram(
            id: upperBodyProgramID,
            title: "Upper Body Foundation",
            description: "A three-day upper body split focused on steady strength and hypertrophy work.",
            tags: [.gym, .strength, .muscleGain]
        )

        let strengthProgram = try? WorkoutProgram(
            id: strengthProgramID,
            title: "Strength Essentials",
            description: "A barbell-focused plan built around compound lifts and simple linear progression.",
            tags: [.gym, .strength, .muscleGain]
        )

        let conditioningProgram = try? WorkoutProgram(
            id: conditioningProgramID,
            title: "Conditioning Boost",
            description: "A faster, lighter training block for work capacity, cardio, and bodyweight output.",
            tags: [.home, .cardio, .hiit, .mobility, .bodyweight]
        )

        let mobilityProgram = try? WorkoutProgram(
            id: mobilityProgramID,
            title: "Mobility Reset",
            description: "A recovery-focused program for posture, movement quality, and full-body mobility.",
            tags: [.home, .mobility, .bodyweight]
        )

        let homeProgramCatalogMetadataByProgramID: [UUID: HomeProgramCatalogMetadata] = [
            upperBodyProgramID: HomeProgramCatalogMetadata(
                isRecommended: true,
                isPopular: true,
                rateScore: 4.8
            ),
            strengthProgramID: HomeProgramCatalogMetadata(
                isRecommended: true,
                isPopular: true,
                rateScore: 4.9
            ),
            conditioningProgramID: HomeProgramCatalogMetadata(
                isRecommended: false,
                isPopular: true,
                rateScore: 4.6
            ),
            mobilityProgramID: HomeProgramCatalogMetadata(
                isRecommended: false,
                isPopular: false,
                rateScore: nil
            )
        ]

        let workoutDays = compact([
            try? WorkoutDay(id: pushDayID, programId: upperBodyProgramID, title: "Push", orderIndex: 0),
            try? WorkoutDay(id: pullDayID, programId: upperBodyProgramID, title: "Pull", orderIndex: 1),
            try? WorkoutDay(id: armsDayID, programId: upperBodyProgramID, title: "Arms & Delts", orderIndex: 2),
            try? WorkoutDay(id: squatDayID, programId: strengthProgramID, title: "Squat Focus", orderIndex: 0),
            try? WorkoutDay(id: upperStrengthDayID, programId: strengthProgramID, title: "Upper Strength", orderIndex: 1),
            try? WorkoutDay(id: deadliftDayID, programId: strengthProgramID, title: "Deadlift Focus", orderIndex: 2),
            try? WorkoutDay(id: sprintDayID, programId: conditioningProgramID, title: "Sprint Intervals", orderIndex: 0),
            try? WorkoutDay(id: conditioningDayID, programId: conditioningProgramID, title: "Leg Conditioning", orderIndex: 1),
            try? WorkoutDay(id: coreDayID, programId: conditioningProgramID, title: "Core Density", orderIndex: 2),
            try? WorkoutDay(id: flowDayID, programId: mobilityProgramID, title: "Flow Reset", orderIndex: 0),
            try? WorkoutDay(id: recoveryDayID, programId: mobilityProgramID, title: "Recovery Mobility", orderIndex: 1)
        ])

        let exercises = compact([
            try? Exercise(id: benchExerciseID, name: "Bench Press", muscleGroup: .chest),
            try? Exercise(id: pressExerciseID, name: "Overhead Press", muscleGroup: .shoulders),
            try? Exercise(id: rowExerciseID, name: "Barbell Row", muscleGroup: .back),
            try? Exercise(id: squatExerciseID, name: "Back Squat", muscleGroup: .legs),
            try? Exercise(id: deadliftExerciseID, name: "Deadlift", muscleGroup: .fullBody),
            try? Exercise(id: runExerciseID, name: "Sprint Run", muscleGroup: .cardio),
            try? Exercise(id: lungeExerciseID, name: "Walking Lunge", muscleGroup: .legs),
            try? Exercise(id: inclinePressExerciseID, name: "Incline Dumbbell Press", muscleGroup: .chest),
            try? Exercise(id: pullUpExerciseID, name: "Pull-Up", muscleGroup: .back),
            try? Exercise(id: lateralRaiseExerciseID, name: "Lateral Raise", muscleGroup: .shoulders),
            try? Exercise(id: plankExerciseID, name: "Plank Hold", muscleGroup: .core),
            try? Exercise(id: burpeeExerciseID, name: "Burpee", muscleGroup: .cardio),
            try? Exercise(id: catCowExerciseID, name: "Cat-Cow", muscleGroup: .core),
            try? Exercise(id: hipBridgeExerciseID, name: "Hip Bridge", muscleGroup: .legs)
        ])

        let dayExercises = compact([
            try? WorkoutDayExercise(
                id: uuid("88888888-8888-8888-8888-888888888888"),
                workoutDayId: pushDayID,
                exerciseId: benchExerciseID,
                targetSets: 4,
                targetReps: 8,
                targetWeight: 60,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("99999999-9999-9999-9999-999999999999"),
                workoutDayId: pushDayID,
                exerciseId: pressExerciseID,
                targetSets: 3,
                targetReps: 10,
                targetWeight: 35,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("9a9a9a9a-9a9a-9a9a-9a9a-9a9a9a9a9a9a"),
                workoutDayId: pushDayID,
                exerciseId: inclinePressExerciseID,
                targetSets: 3,
                targetReps: 12,
                targetWeight: 22,
                orderIndex: 2
            ),
            try? WorkoutDayExercise(
                id: uuid("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                workoutDayId: pullDayID,
                exerciseId: rowExerciseID,
                targetSets: 4,
                targetReps: 10,
                targetWeight: 50,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("abababab-abab-abab-abab-abababababaa"),
                workoutDayId: pullDayID,
                exerciseId: pullUpExerciseID,
                targetSets: 4,
                targetReps: 8,
                targetWeight: nil,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("acacacac-acac-acac-acac-acacacacacaa"),
                workoutDayId: armsDayID,
                exerciseId: lateralRaiseExerciseID,
                targetSets: 4,
                targetReps: 15,
                targetWeight: 8,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("abababab-abab-abab-abab-abababababab"),
                workoutDayId: squatDayID,
                exerciseId: squatExerciseID,
                targetSets: 5,
                targetReps: 5,
                targetWeight: 90,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("adadadad-adad-adad-adad-adadadadadad"),
                workoutDayId: upperStrengthDayID,
                exerciseId: benchExerciseID,
                targetSets: 4,
                targetReps: 6,
                targetWeight: 70,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae"),
                workoutDayId: upperStrengthDayID,
                exerciseId: rowExerciseID,
                targetSets: 4,
                targetReps: 8,
                targetWeight: 60,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("afafafaf-afaf-afaf-afaf-afafafafafaf"),
                workoutDayId: deadliftDayID,
                exerciseId: deadliftExerciseID,
                targetSets: 4,
                targetReps: 5,
                targetWeight: 110,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b0b0b0"),
                workoutDayId: sprintDayID,
                exerciseId: runExerciseID,
                targetSets: 6,
                targetReps: 1,
                targetWeight: nil,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1"),
                workoutDayId: conditioningDayID,
                exerciseId: lungeExerciseID,
                targetSets: 4,
                targetReps: 12,
                targetWeight: 20,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2"),
                workoutDayId: conditioningDayID,
                exerciseId: burpeeExerciseID,
                targetSets: 4,
                targetReps: 10,
                targetWeight: nil,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3"),
                workoutDayId: coreDayID,
                exerciseId: plankExerciseID,
                targetSets: 5,
                targetReps: 1,
                targetWeight: nil,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b4b4"),
                workoutDayId: flowDayID,
                exerciseId: catCowExerciseID,
                targetSets: 3,
                targetReps: 12,
                targetWeight: nil,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b5b5"),
                workoutDayId: recoveryDayID,
                exerciseId: hipBridgeExerciseID,
                targetSets: 3,
                targetReps: 15,
                targetWeight: nil,
                orderIndex: 0
            )
        ])

        let sessions = compact([
            try? WorkoutSession(
                id: activeSessionID,
                userId: currentUserID,
                workoutDayId: pushDayID,
                startedAt: activeSessionStartedAt
            ),
            try? WorkoutSession(
                id: completedStrengthSessionID,
                userId: currentUserID,
                workoutDayId: squatDayID,
                status: .completed,
                startedAt: completedStrengthStartedAt,
                completedAt: completedStrengthEndedAt
            ),
            try? WorkoutSession(
                id: secondUserSessionID,
                userId: secondUserID,
                workoutDayId: upperStrengthDayID,
                status: .completed,
                startedAt: secondUserSessionStartedAt,
                completedAt: secondUserSessionEndedAt
            )
        ])

        let exerciseLogs = compact([
            try? ExerciseLog(
                id: uuid("cccccccc-cccc-cccc-cccc-cccccccccccc"),
                sessionId: activeSessionID,
                workoutDayExerciseId: uuid("88888888-8888-8888-8888-888888888888"),
                weight: 60,
                reps: 8,
                setNumber: 1,
                performedAt: activeSessionStartedAt.addingTimeInterval(300)
            ),
            try? ExerciseLog(
                id: uuid("dddddddd-dddd-dddd-dddd-dddddddddddd"),
                sessionId: activeSessionID,
                workoutDayExerciseId: uuid("88888888-8888-8888-8888-888888888888"),
                weight: 60,
                reps: 7,
                setNumber: 2,
                performedAt: activeSessionStartedAt.addingTimeInterval(660)
            ),
            try? ExerciseLog(
                id: uuid("dededede-dede-dede-dede-dededededede"),
                sessionId: activeSessionID,
                workoutDayExerciseId: uuid("99999999-9999-9999-9999-999999999999"),
                weight: 35,
                reps: 10,
                setNumber: 1,
                performedAt: activeSessionStartedAt.addingTimeInterval(1_020)
            ),
            try? ExerciseLog(
                id: uuid("dfdfdfdf-dfdf-dfdf-dfdf-dfdfdfdfdfdf"),
                sessionId: completedStrengthSessionID,
                workoutDayExerciseId: uuid("abababab-abab-abab-abab-abababababab"),
                weight: 90,
                reps: 5,
                setNumber: 1,
                performedAt: completedStrengthStartedAt.addingTimeInterval(420)
            ),
            try? ExerciseLog(
                id: uuid("e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0"),
                sessionId: completedStrengthSessionID,
                workoutDayExerciseId: uuid("abababab-abab-abab-abab-abababababab"),
                weight: 92.5,
                reps: 5,
                setNumber: 2,
                performedAt: completedStrengthStartedAt.addingTimeInterval(900)
            ),
            try? ExerciseLog(
                id: uuid("e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1"),
                sessionId: secondUserSessionID,
                workoutDayExerciseId: uuid("adadadad-adad-adad-adad-adadadadadad"),
                weight: 72.5,
                reps: 6,
                setNumber: 1,
                performedAt: secondUserSessionStartedAt.addingTimeInterval(360)
            ),
            try? ExerciseLog(
                id: uuid("e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2"),
                sessionId: secondUserSessionID,
                workoutDayExerciseId: uuid("aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae"),
                weight: 62.5,
                reps: 8,
                setNumber: 1,
                performedAt: secondUserSessionStartedAt.addingTimeInterval(780)
            )
        ])

        return MockDataStore(
            users: compact([currentUser, secondUser]),
            programs: compact([upperBodyProgram, strengthProgram, conditioningProgram, mobilityProgram]),
            homeProgramCatalogMetadataByProgramID: homeProgramCatalogMetadataByProgramID,
            workoutDays: workoutDays,
            dayExercises: dayExercises,
            exercises: exercises,
            sessions: sessions,
            exerciseLogs: exerciseLogs,
            currentUserID: currentUserID
        )
    }

    /// Keeps fixture creation readable while ignoring entities that failed domain validation.
    private static func compact<T>(_ values: [T?]) -> [T] {
        values.compactMap { $0 }
    }

    private static func uuid(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue) ?? UUID()
    }
}
