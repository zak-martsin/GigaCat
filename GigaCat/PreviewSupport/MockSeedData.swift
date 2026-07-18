import Foundation

struct MockSeedContext {
    let currentUserID: UUID
    let secondUserID: UUID

    let upperBodyProgramID: UUID
    let strengthProgramID: UUID
    let conditioningProgramID: UUID
    let mobilityProgramID: UUID

    let pushDayID: UUID
    let pullDayID: UUID
    let armsDayID: UUID
    let squatDayID: UUID
    let upperStrengthDayID: UUID
    let deadliftDayID: UUID
    let sprintDayID: UUID
    let conditioningDayID: UUID
    let coreDayID: UUID
    let flowDayID: UUID
    let recoveryDayID: UUID

    let benchExerciseID: UUID
    let pressExerciseID: UUID
    let rowExerciseID: UUID
    let squatExerciseID: UUID
    let deadliftExerciseID: UUID
    let runExerciseID: UUID
    let lungeExerciseID: UUID
    let inclinePressExerciseID: UUID
    let pullUpExerciseID: UUID
    let lateralRaiseExerciseID: UUID
    let plankExerciseID: UUID
    let burpeeExerciseID: UUID
    let catCowExerciseID: UUID
    let hipBridgeExerciseID: UUID

    let activeSessionID: UUID
    let completedStrengthSessionID: UUID
    let secondUserSessionID: UUID

    let now: Date
    let createdAt: Date
    let activeSessionStartedAt: Date
    let completedStrengthStartedAt: Date
    let completedStrengthEndedAt: Date
    let secondUserSessionStartedAt: Date
    let secondUserSessionEndedAt: Date
}

/// Fixture builder for previews, tests, and early feature development before real persistence exists.
enum MockSeedData {
    private static func makeContext() -> MockSeedContext {
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

        return MockSeedContext(
            currentUserID: currentUserID,
            secondUserID: secondUserID,
            upperBodyProgramID: upperBodyProgramID,
            strengthProgramID: strengthProgramID,
            conditioningProgramID: conditioningProgramID,
            mobilityProgramID: mobilityProgramID,
            pushDayID: pushDayID,
            pullDayID: pullDayID,
            armsDayID: armsDayID,
            squatDayID: squatDayID,
            upperStrengthDayID: upperStrengthDayID,
            deadliftDayID: deadliftDayID,
            sprintDayID: sprintDayID,
            conditioningDayID: conditioningDayID,
            coreDayID: coreDayID,
            flowDayID: flowDayID,
            recoveryDayID: recoveryDayID,
            benchExerciseID: benchExerciseID,
            pressExerciseID: pressExerciseID,
            rowExerciseID: rowExerciseID,
            squatExerciseID: squatExerciseID,
            deadliftExerciseID: deadliftExerciseID,
            runExerciseID: runExerciseID,
            lungeExerciseID: lungeExerciseID,
            inclinePressExerciseID: inclinePressExerciseID,
            pullUpExerciseID: pullUpExerciseID,
            lateralRaiseExerciseID: lateralRaiseExerciseID,
            plankExerciseID: plankExerciseID,
            burpeeExerciseID: burpeeExerciseID,
            catCowExerciseID: catCowExerciseID,
            hipBridgeExerciseID: hipBridgeExerciseID,
            activeSessionID: activeSessionID,
            completedStrengthSessionID: completedStrengthSessionID,
            secondUserSessionID: secondUserSessionID,
            now: now,
            createdAt: createdAt,
            activeSessionStartedAt: activeSessionStartedAt,
            completedStrengthStartedAt: completedStrengthStartedAt,
            completedStrengthEndedAt: completedStrengthEndedAt,
            secondUserSessionStartedAt: secondUserSessionStartedAt,
            secondUserSessionEndedAt: secondUserSessionEndedAt
        )
    }

    /// Creates a coherent graph of users, programs, workout days, exercises, sessions, and logs.
    static func makeStore() -> MockDataStore {
        let context = makeContext()
        let users = makeUsers(context)
        let programs = makePrograms(context)
        let homeProgramCatalogMetadataByProgramID = makeHomeProgramCatalogMetadata(context)
        let workoutDays = makeWorkoutDays(context)
        let exercises = makeExercises(context)
        let dayExercises = makeDayExercises(context)
        let sessions = makeSessions(context)
        let exerciseLogs = makeExerciseLogs(context)
        let currentUserID = context.currentUserID

        return MockDataStore(
            users: users,
            programs: programs,
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
    static func compact<T>(_ values: [T?]) -> [T] {
        values.compactMap { $0 }
    }

    static func uuid(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue) ?? UUID()
    }
}
