import Foundation

/// Provider-independent app profile whose ID matches the Supabase Auth account.
struct User: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let selectedProgramId: UUID?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        selectedProgramId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns a new user value with an updated selected workout program.
    func selectingProgram(_ programId: UUID?, updatedAt: Date = Date()) -> User {
        User(
            id: id,
            selectedProgramId: programId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
