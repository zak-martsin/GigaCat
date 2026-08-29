import Foundation

/// Builds deterministic preview and test activity on top of the production default catalog.
enum MockSeedData {
    static func makeStore(now: Date = Date()) throws -> MockDataStore {
        let context = makeContext(now: now)
        let catalog = try BundledDefaultCatalog.load()

        return MockDataStore(
            users: makeUsers(context),
            programs: catalog.programs,
            workoutDays: catalog.workoutDays,
            dayExercises: catalog.dayExercises,
            exercises: catalog.exercises,
            sessions: try makeSessions(context),
            exerciseLogs: try makeExerciseLogs(context),
            currentUserID: context.currentUserID
        )
    }

    static func uuid(_ rawValue: String) -> UUID {
        guard let value = UUID(uuidString: rawValue) else {
            preconditionFailure("Invalid stable fixture UUID: \(rawValue)")
        }
        return value
    }

    private static func makeContext(now: Date) -> MockSeedContext {
        MockSeedContext(
            currentUserID: uuid("11111111-1111-1111-1111-111111111111"),
            secondUserID: uuid("11111111-1111-1111-1111-222222222222"),
            currentProgramID: uuid("20000000-0000-0000-0000-000000000001"),
            secondUserProgramID: uuid("20000000-0000-0000-0000-000000000002"),
            activeWorkoutDayID: uuid("30000000-0000-0000-0000-000000000001"),
            completedWorkoutDayID: uuid("30000000-0000-0000-0000-000000000003"),
            secondUserWorkoutDayID: uuid("30000000-0000-0000-0000-000000000004"),
            activeSessionID: uuid("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
            completedSessionID: uuid("bcbcbcbc-bcbc-bcbc-bcbc-bcbcbcbcbcbc"),
            secondUserSessionID: uuid("bdbdbdbd-bdbd-bdbd-bdbd-bdbdbdbdbdbd"),
            now: now
        )
    }
}

struct MockSeedContext {
    let currentUserID: UUID
    let secondUserID: UUID
    let currentProgramID: UUID
    let secondUserProgramID: UUID
    let activeWorkoutDayID: UUID
    let completedWorkoutDayID: UUID
    let secondUserWorkoutDayID: UUID
    let activeSessionID: UUID
    let completedSessionID: UUID
    let secondUserSessionID: UUID
    let now: Date

    var createdAt: Date { now.addingTimeInterval(-86_400 * 12) }
    var activeSessionStartedAt: Date { now.addingTimeInterval(-1_800) }
    var completedSessionStartedAt: Date { now.addingTimeInterval(-86_400 * 2) }
    var completedSessionEndedAt: Date { completedSessionStartedAt.addingTimeInterval(2_700) }
    var secondUserSessionStartedAt: Date { now.addingTimeInterval(-86_400 * 3) }
    var secondUserSessionEndedAt: Date { secondUserSessionStartedAt.addingTimeInterval(1_900) }
}
