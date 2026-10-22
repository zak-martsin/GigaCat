import Foundation
import Testing
@testable import GigaCat

@MainActor
struct WorkoutSessionExpirationMonitorTests {

    @Test
    func scheduledResultCreatesOneTimerAndRefreshUsesObservedUser() async {
        let userID = UUID()
        let now = Date(timeIntervalSince1970: 10_000)
        let expirationDate = now.addingTimeInterval(60)
        let service = ExpirationServiceStub(
            results: [.scheduled(expirationDate), .noActiveSession]
        )
        let sleepRecorder = ExpirationSleepRecorder()
        let monitor = WorkoutSessionExpirationMonitor(
            service: service,
            now: { now },
            sleepUntil: sleepRecorder.sleep,
            onSessionExpired: {}
        )

        await monitor.refresh(for: userID)
        while await sleepRecorder.dates.isEmpty {
            await Task.yield()
        }
        await monitor.refresh()

        #expect(await sleepRecorder.dates == [expirationDate])
        #expect(await service.userIDs == [userID, userID])
        #expect(await service.reconciliationDates == [now, now])
    }

    @Test
    func completedResultNotifiesTheApplication() async throws {
        let userID = UUID()
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let completedSession = try WorkoutSession(
            userId: userID,
            workoutDayId: UUID(),
            status: .completed,
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(60)
        )
        let service = ExpirationServiceStub(
            results: [.completed(completedSession)]
        )
        var notificationCount = 0
        let monitor = WorkoutSessionExpirationMonitor(
            service: service,
            now: { startedAt.addingTimeInterval(60) },
            onSessionExpired: { notificationCount += 1 }
        )

        let didExpire = await monitor.refresh(for: userID)

        #expect(didExpire)
        #expect(notificationCount == 1)
    }
}

private actor ExpirationServiceStub: WorkoutSessionExpirationServicing {
    private var results: [WorkoutSessionExpirationResult]
    private(set) var userIDs: [UUID] = []
    private(set) var reconciliationDates: [Date] = []

    init(results: [WorkoutSessionExpirationResult]) {
        self.results = results
    }

    func reconcile(
        for userID: UUID,
        now: Date
    ) async throws -> WorkoutSessionExpirationResult {
        userIDs.append(userID)
        reconciliationDates.append(now)
        return results.isEmpty ? .noActiveSession : results.removeFirst()
    }
}

private actor ExpirationSleepRecorder {
    private(set) var dates: [Date] = []

    func sleep(until date: Date) async throws {
        dates.append(date)
        throw CancellationError()
    }
}
