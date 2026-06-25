import Foundation

/// Predefined training program composed of ordered workout days.
struct WorkoutProgram: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let description: String

    init(
        id: UUID = UUID(),
        title: String,
        description: String
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "title")
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "description")
        }

        self.id = id
        self.title = title
        self.description = description
    }
}
