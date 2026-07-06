import Foundation

/// Predefined training program composed of ordered workout days.
struct WorkoutProgram: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let tags: [WorkoutProgramTag]

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        tags: [WorkoutProgramTag] = []
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
        self.tags = tags
    }
}
