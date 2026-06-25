import Foundation

/// Reusable exercise definition shared by workout plans and logged sets.
struct Exercise: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let muscleGroup: ExerciseMuscleGroup

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: ExerciseMuscleGroup
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "name")
        }

        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
