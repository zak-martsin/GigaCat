import Foundation
import Testing
@testable import GigaCat

struct WorkoutSessionExpirationPolicyTests {
    private let policy = WorkoutSessionExpirationPolicy()
    private let startedAt = Date(timeIntervalSince1970: 10_000)

    @Test
    func sessionWithoutActivityExpiresTwoHoursAfterStart() {
        let expirationDate = policy.expirationDate(
            startedAt: startedAt,
            lastActivityAt: nil
        )

        #expect(expirationDate == startedAt.addingTimeInterval(2 * 60 * 60))
    }

    @Test
    func recentActivityMovesTheInactivityDeadline() {
        let lastActivityAt = startedAt.addingTimeInterval(60 * 60)

        let expirationDate = policy.expirationDate(
            startedAt: startedAt,
            lastActivityAt: lastActivityAt
        )

        #expect(expirationDate == startedAt.addingTimeInterval(3 * 60 * 60))
    }

    @Test
    func absoluteLimitWinsOverRecentActivity() {
        let lastActivityAt = startedAt.addingTimeInterval(4.5 * 60 * 60)

        let expirationDate = policy.expirationDate(
            startedAt: startedAt,
            lastActivityAt: lastActivityAt
        )

        #expect(expirationDate == startedAt.addingTimeInterval(5 * 60 * 60))
    }
}
