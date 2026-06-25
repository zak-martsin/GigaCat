import Foundation

/// Fixture builder for previews, tests, and early feature development before real persistence exists.
enum MockSeedData {
    /// Creates one coherent user/program/session graph so screens can exercise real repository flows.
    static func makeStore() -> MockDataStore {
        let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let programID = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        let pushDayID = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()
        let pullDayID = UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID()
        let benchExerciseID = UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID()
        let pressExerciseID = UUID(uuidString: "66666666-6666-6666-6666-666666666666") ?? UUID()
        let rowExerciseID = UUID(uuidString: "77777777-7777-7777-7777-777777777777") ?? UUID()
        let pushBenchAssignmentID = UUID(uuidString: "88888888-8888-8888-8888-888888888888") ?? UUID()
        let pushPressAssignmentID = UUID(uuidString: "99999999-9999-9999-9999-999999999999") ?? UUID()
        let pullRowAssignmentID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") ?? UUID()
        let sessionID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") ?? UUID()
        let firstLogID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc") ?? UUID()
        let secondLogID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd") ?? UUID()

        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let sessionStartedAt = Date(timeIntervalSince1970: 1_700_000_600)

        let user = try? User(
            id: userID,
            appleUserId: "mock-apple-user",
            selectedProgramId: programID,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let program = try? WorkoutProgram(
            id: programID,
            title: "Upper Body Foundation",
            description: "A simple two-day split for early feature development."
        )

        let pushDay = try? WorkoutDay(
            id: pushDayID,
            programId: programID,
            title: "Push",
            orderIndex: 0
        )

        let pullDay = try? WorkoutDay(
            id: pullDayID,
            programId: programID,
            title: "Pull",
            orderIndex: 1
        )

        let bench = try? Exercise(
            id: benchExerciseID,
            name: "Bench Press",
            muscleGroup: .chest
        )

        let overheadPress = try? Exercise(
            id: pressExerciseID,
            name: "Overhead Press",
            muscleGroup: .shoulders
        )

        let row = try? Exercise(
            id: rowExerciseID,
            name: "Barbell Row",
            muscleGroup: .back
        )

        let pushBenchAssignment = try? WorkoutDayExercise(
            id: pushBenchAssignmentID,
            workoutDayId: pushDayID,
            exerciseId: benchExerciseID,
            targetSets: 4,
            targetReps: 8,
            targetWeight: 60,
            orderIndex: 0
        )

        let pushPressAssignment = try? WorkoutDayExercise(
            id: pushPressAssignmentID,
            workoutDayId: pushDayID,
            exerciseId: pressExerciseID,
            targetSets: 3,
            targetReps: 10,
            targetWeight: 35,
            orderIndex: 1
        )

        let pullRowAssignment = try? WorkoutDayExercise(
            id: pullRowAssignmentID,
            workoutDayId: pullDayID,
            exerciseId: rowExerciseID,
            targetSets: 4,
            targetReps: 10,
            targetWeight: 50,
            orderIndex: 0
        )

        let session = try? WorkoutSession(
            id: sessionID,
            userId: userID,
            workoutDayId: pushDayID,
            startedAt: sessionStartedAt
        )

        let firstLog = try? ExerciseLog(
            id: firstLogID,
            sessionId: sessionID,
            exerciseId: benchExerciseID,
            weight: 60,
            reps: 8,
            setNumber: 1
        )

        let secondLog = try? ExerciseLog(
            id: secondLogID,
            sessionId: sessionID,
            exerciseId: benchExerciseID,
            weight: 60,
            reps: 7,
            setNumber: 2
        )

        return MockDataStore(
            users: compact([user]),
            programs: compact([program]),
            workoutDays: compact([pushDay, pullDay]),
            dayExercises: compact([pushBenchAssignment, pushPressAssignment, pullRowAssignment]),
            exercises: compact([bench, overheadPress, row]),
            sessions: compact([session]),
            exerciseLogs: compact([firstLog, secondLog]),
            currentUserID: userID
        )
    }

    /// Keeps fixture creation readable while ignoring entities that failed domain validation.
    private static func compact<T>(_ values: [T?]) -> [T] {
        values.compactMap { $0 }
    }
}
