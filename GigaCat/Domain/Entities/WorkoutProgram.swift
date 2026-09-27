import Foundation

/// Predefined training program composed of ordered workout days.
struct WorkoutProgram: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    /// Identifier of the user who created the program. `nil` marks a default catalog program.
    let authorId: UUID?
    let audience: WorkoutProgramAudience?
    let isActive: Bool
    let title: String
    let description: String
    let tags: [WorkoutProgramTag]
    let artwork: ProgramArtwork?

    var isDefaultCatalogProgram: Bool {
        authorId == nil
    }

    init(
        id: UUID = UUID(),
        authorId: UUID? = nil,
        audience: WorkoutProgramAudience? = nil,
        isActive: Bool = true,
        title: String,
        description: String,
        tags: [WorkoutProgramTag] = [],
        artwork: ProgramArtwork? = nil
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "title")
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "description")
        }

        self.id = id
        self.authorId = authorId
        self.audience = audience
        self.isActive = isActive
        self.title = title
        self.description = description
        self.tags = tags
        self.artwork = artwork
    }
}
