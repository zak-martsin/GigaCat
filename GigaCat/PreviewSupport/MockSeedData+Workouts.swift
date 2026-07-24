import Foundation

extension MockSeedData {

    /// Combines all planned workout-day exercise links so previews and tests can load the full catalog at once.
    static func makeDayExercises(_ context: MockSeedContext) -> [WorkoutDayExercise] {
        makeUpperBodyDayExercises(context)
            + makeStrengthDayExercises(context)
            + makeConditioningDayExercises(context)
            + makeMobilityDayExercises(context)
    }

    /// Seeds the upper-body split with exercises grouped under Push, Pull, and Arms days.
    static func makeUpperBodyDayExercises(_ context: MockSeedContext) -> [WorkoutDayExercise] {
        compact([
            try? WorkoutDayExercise(
                id: uuid("88888888-8888-8888-8888-888888888888"),
                workoutDayId: context.pushDayID,
                exerciseId: context.benchExerciseID,
                targetSets: 4,
                targetReps: 8,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("99999999-9999-9999-9999-999999999999"),
                workoutDayId: context.pushDayID,
                exerciseId: context.pressExerciseID,
                targetSets: 3,
                targetReps: 10,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("9a9a9a9a-9a9a-9a9a-9a9a-9a9a9a9a9a9a"),
                workoutDayId: context.pushDayID,
                exerciseId: context.inclinePressExerciseID,
                targetSets: 3,
                targetReps: 12,
                orderIndex: 2
            ),
            try? WorkoutDayExercise(
                id: uuid("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                workoutDayId: context.pullDayID,
                exerciseId: context.rowExerciseID,
                targetSets: 4,
                targetReps: 10,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("abababab-abab-abab-abab-abababababaa"),
                workoutDayId: context.pullDayID,
                exerciseId: context.pullUpExerciseID,
                targetSets: 4,
                targetReps: 8,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("acacacac-acac-acac-acac-acacacacacaa"),
                workoutDayId: context.armsDayID,
                exerciseId: context.lateralRaiseExerciseID,
                targetSets: 4,
                targetReps: 15,
                orderIndex: 0
            )
        ])
    }

    /// Seeds the strength program with compound lift prescriptions across squat, upper, and deadlift days.
    static func makeStrengthDayExercises(_ context: MockSeedContext) -> [WorkoutDayExercise] {
        compact([
            try? WorkoutDayExercise(
                id: uuid("abababab-abab-abab-abab-abababababab"),
                workoutDayId: context.squatDayID,
                exerciseId: context.squatExerciseID,
                targetSets: 5,
                targetReps: 5,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("adadadad-adad-adad-adad-adadadadadad"),
                workoutDayId: context.upperStrengthDayID,
                exerciseId: context.benchExerciseID,
                targetSets: 4,
                targetReps: 6,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae"),
                workoutDayId: context.upperStrengthDayID,
                exerciseId: context.rowExerciseID,
                targetSets: 4,
                targetReps: 8,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("afafafaf-afaf-afaf-afaf-afafafafafaf"),
                workoutDayId: context.deadliftDayID,
                exerciseId: context.deadliftExerciseID,
                targetSets: 4,
                targetReps: 5,
                orderIndex: 0
            )
        ])
    }

    /// Seeds the conditioning program with interval, leg, and core-focused exercise assignments.
    static func makeConditioningDayExercises(_ context: MockSeedContext) -> [WorkoutDayExercise] {
        compact([
            try? WorkoutDayExercise(
                id: uuid("b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b0b0b0"),
                workoutDayId: context.sprintDayID,
                exerciseId: context.runExerciseID,
                targetSets: 6,
                targetReps: 1,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1"),
                workoutDayId: context.conditioningDayID,
                exerciseId: context.lungeExerciseID,
                targetSets: 4,
                targetReps: 12,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2"),
                workoutDayId: context.conditioningDayID,
                exerciseId: context.burpeeExerciseID,
                targetSets: 4,
                targetReps: 10,
                orderIndex: 1
            ),
            try? WorkoutDayExercise(
                id: uuid("b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3"),
                workoutDayId: context.coreDayID,
                exerciseId: context.plankExerciseID,
                targetSets: 5,
                targetReps: 1,
                orderIndex: 0
            )
        ])
    }

    /// Seeds the mobility program with lower-volume recovery and movement-quality work.
    static func makeMobilityDayExercises(_ context: MockSeedContext) -> [WorkoutDayExercise] {
        compact([
            try? WorkoutDayExercise(
                id: uuid("b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b4b4"),
                workoutDayId: context.flowDayID,
                exerciseId: context.catCowExerciseID,
                targetSets: 3,
                targetReps: 12,
                orderIndex: 0
            ),
            try? WorkoutDayExercise(
                id: uuid("b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b5b5"),
                workoutDayId: context.recoveryDayID,
                exerciseId: context.hipBridgeExerciseID,
                targetSets: 3,
                targetReps: 15,
                orderIndex: 0
            )
        ])
    }

    /// Builds workout days in display order so feature code can assume stable navigation through a program.
    static func makeWorkoutDays(_ context: MockSeedContext) -> [WorkoutDay] {
        compact([
            try? WorkoutDay(id: context.pushDayID, programId: context.upperBodyProgramID, title: "Push", orderIndex: 0),
            try? WorkoutDay(id: context.pullDayID, programId: context.upperBodyProgramID, title: "Pull", orderIndex: 1),
            try? WorkoutDay(id: context.armsDayID, programId: context.upperBodyProgramID, title: "Arms & Delts", orderIndex: 2),
            try? WorkoutDay(id: context.squatDayID, programId: context.strengthProgramID, title: "Squat Focus", orderIndex: 0),
            try? WorkoutDay(
                id: context.upperStrengthDayID,
                programId: context.strengthProgramID,
                title: "Upper Strength",
                orderIndex: 1
            ),
            try? WorkoutDay(
                id: context.deadliftDayID,
                programId: context.strengthProgramID,
                title: "Deadlift Focus",
                orderIndex: 2
            ),
            try? WorkoutDay(
                id: context.sprintDayID,
                programId: context.conditioningProgramID,
                title: "Sprint Intervals",
                orderIndex: 0
            ),
            try? WorkoutDay(
                id: context.conditioningDayID,
                programId: context.conditioningProgramID,
                title: "Leg Conditioning",
                orderIndex: 1
            ),
            try? WorkoutDay(
                id: context.coreDayID,
                programId: context.conditioningProgramID,
                title: "Core Density",
                orderIndex: 2
            ),
            try? WorkoutDay(id: context.flowDayID, programId: context.mobilityProgramID, title: "Flow Reset", orderIndex: 0),
            try? WorkoutDay(
                id: context.recoveryDayID,
                programId: context.mobilityProgramID,
                title: "Recovery Mobility",
                orderIndex: 1
            )
        ])
    }

    /// Defines reusable exercise entities separately from their workout-day prescriptions.
    static func makeExercises(_ context: MockSeedContext) -> [Exercise] {
        compact([
            try? Exercise(id: context.benchExerciseID, name: "Bench Press", muscleGroup: .chest),
            try? Exercise(id: context.pressExerciseID, name: "Overhead Press", muscleGroup: .shoulders),
            try? Exercise(id: context.rowExerciseID, name: "Barbell Row", muscleGroup: .back),
            try? Exercise(id: context.squatExerciseID, name: "Back Squat", muscleGroup: .legs),
            try? Exercise(id: context.deadliftExerciseID, name: "Deadlift", muscleGroup: .fullBody),
            try? Exercise(id: context.runExerciseID, name: "Sprint Run", muscleGroup: .cardio),
            try? Exercise(id: context.lungeExerciseID, name: "Walking Lunge", muscleGroup: .legs),
            try? Exercise(
                id: context.inclinePressExerciseID,
                name: "Incline Dumbbell Press",
                muscleGroup: .chest
            ),
            try? Exercise(id: context.pullUpExerciseID, name: "Pull-Up", muscleGroup: .back),
            try? Exercise(id: context.lateralRaiseExerciseID, name: "Lateral Raise", muscleGroup: .shoulders),
            try? Exercise(id: context.plankExerciseID, name: "Plank Hold", muscleGroup: .core),
            try? Exercise(id: context.burpeeExerciseID, name: "Burpee", muscleGroup: .cardio),
            try? Exercise(id: context.catCowExerciseID, name: "Cat-Cow", muscleGroup: .core),
            try? Exercise(id: context.hipBridgeExerciseID, name: "Hip Bridge", muscleGroup: .legs)
        ])
    }

}
