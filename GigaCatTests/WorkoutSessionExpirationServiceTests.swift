import Foundation
import Testing
@testable import GigaCat

struct WorkoutSessionExpirationServiceTests {

    @Test
    func returnsNoActiveSessionWithoutMutatingHistory() async throws {
        let userID = UUID()
        let service = makeService(userID: userID)

        let result = try await service.reconcile(
            for: userID,
            now: Date(timeIntervalSince1970: 20_000)
        )

        #expect(result == .noActiveSession)
    }

    @Test
    func schedulesFromTheLatestExerciseLog() async throws {
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let lastActivityAt = startedAt.addingTimeInterval(60 * 60)
        let fixture = try makeActiveSessionFixture(
            startedAt: startedAt,
            logDates: [startedAt, lastActivityAt]
        )

        let result = try await fixture.service.reconcile(
            for: fixture.userID,
            now: startedAt.addingTimeInterval(2 * 60 * 60)
        )

        #expect(result == .scheduled(lastActivityAt.addingTimeInterval(2 * 60 * 60)))
    }

    @Test
    func completesAtTheAbsoluteDeadlineInsteadOfReconciliationTime() async throws {
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let fixture = try makeActiveSessionFixture(
            startedAt: startedAt,
            logDates: [startedAt.addingTimeInterval(4 * 60 * 60)]
        )
        let deadline = startedAt.addingTimeInterval(5 * 60 * 60)

        let result = try await fixture.service.reconcile(
            for: fixture.userID,
            now: deadline.addingTimeInterval(30 * 60)
        )

        let completedSession = try #require(
            try await fixture.repository.fetchSessions(for: fixture.userID).first
        )
        #expect(result == .completed(completedSession))
        #expect(completedSession.status == .completed)
        #expect(completedSession.completedAt == deadline)
    }
}

private extension WorkoutSessionExpirationServiceTests {
    struct Fixture {
        let userID: UUID
        let repository: MockWorkoutRepository
        let service: WorkoutSessionExpirationService
    }

    func makeService(userID: UUID) -> WorkoutSessionExpirationService {
        let repository = MockWorkoutRepository(
            store: MockDataStore(users: [User(id: userID)])
        )
        return WorkoutSessionExpirationService(workoutRepository: repository)
    }

    func makeActiveSessionFixture(
        startedAt: Date,
        logDates: [Date]
    ) throws -> Fixture {
        let userID = UUID()
        let session = try WorkoutSession(
            userId: userID,
            workoutDayId: UUID(),
            startedAt: startedAt
        )
        let logs = try logDates.enumerated().map { index, date in
            try ExerciseLog(
                sessionId: session.id,
                workoutDayExerciseId: UUID(),
                weight: 50,
                reps: 10,
                setNumber: index + 1,
                performedAt: date
            )
        }
        let repository = MockWorkoutRepository(
            store: MockDataStore(
                users: [User(id: userID)],
                sessions: [session],
                exerciseLogs: logs
            )
        )
        return Fixture(
            userID: userID,
            repository: repository,
            service: WorkoutSessionExpirationService(workoutRepository: repository)
        )
    }
}
