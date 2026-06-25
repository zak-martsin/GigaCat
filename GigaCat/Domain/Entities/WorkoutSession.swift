import Foundation

/// User-owned workout execution record tied to a planned workout day.
struct WorkoutSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let workoutDayId: UUID
    let status: WorkoutSessionStatus
    let startedAt: Date
    let completedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID,
        workoutDayId: UUID,
        status: WorkoutSessionStatus = .inProgress,
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) throws {
        if let completedAt {
            guard completedAt >= startedAt else {
                throw DomainValidationError.invalidCompletionDate
            }

            guard status == .completed else {
                throw DomainValidationError.invalidSessionTransition
            }
        }

        if status == .completed, completedAt == nil {
            throw DomainValidationError.invalidSessionTransition
        }

        self.id = id
        self.userId = userId
        self.workoutDayId = workoutDayId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    // MARK: - Lifecycle

    var isActive: Bool {
        status == .inProgress
    }

    /// Completes an in-progress session and preserves the original identity and start date.
    func markCompleted(at date: Date = Date()) throws -> WorkoutSession {
        guard status == .inProgress else {
            throw DomainValidationError.invalidSessionTransition
        }

        guard date >= startedAt else {
            throw DomainValidationError.invalidCompletionDate
        }

        return try WorkoutSession(
            id: id,
            userId: userId,
            workoutDayId: workoutDayId,
            status: .completed,
            startedAt: startedAt,
            completedAt: date
        )
    }
}
