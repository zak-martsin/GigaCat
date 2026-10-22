import Foundation

/// Defines when an active workout session becomes stale.
struct WorkoutSessionExpirationPolicy: Sendable {
    let inactivityInterval: TimeInterval
    let maximumDuration: TimeInterval

    init(
        inactivityInterval: TimeInterval = 2 * 60 * 60,
        maximumDuration: TimeInterval = 5 * 60 * 60
    ) {
        self.inactivityInterval = inactivityInterval
        self.maximumDuration = maximumDuration
    }

    /// Uses the earlier of the inactivity deadline and the absolute session limit.
    func expirationDate(
        startedAt: Date,
        lastActivityAt: Date?
    ) -> Date {
        let effectiveLastActivityAt = max(lastActivityAt ?? startedAt, startedAt)
        let inactivityDeadline = effectiveLastActivityAt.addingTimeInterval(inactivityInterval)
        let absoluteDeadline = startedAt.addingTimeInterval(maximumDuration)
        return min(inactivityDeadline, absoluteDeadline)
    }
}
