import Foundation

/// Planned training day inside a workout program, such as Push or Legs.
struct WorkoutDay: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let programId: UUID
    let title: String
    let orderIndex: Int

    init(
        id: UUID = UUID(),
        programId: UUID,
        title: String,
        orderIndex: Int
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "title")
        }

        guard orderIndex >= 0 else {
            throw DomainValidationError.negativeValue(field: "orderIndex")
        }

        self.id = id
        self.programId = programId
        self.title = title
        self.orderIndex = orderIndex
    }
}
