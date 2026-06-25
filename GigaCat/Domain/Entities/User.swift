import Foundation

/// Authenticated app user that owns workout history and a selected program.
struct User: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let appleUserId: String
    let selectedProgramId: UUID?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        appleUserId: String,
        selectedProgramId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard !appleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "appleUserId")
        }

        self.id = id
        self.appleUserId = appleUserId
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns a new user value with an updated selected workout program.
    func selectingProgram(_ programId: UUID?, updatedAt: Date = Date()) -> User {
        User(
            id: id,
            appleUserId: appleUserId,
            selectedProgramId: programId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            skipValidation: true
        )
    }

    private init(
        id: UUID,
        appleUserId: String,
        selectedProgramId: UUID?,
        createdAt: Date,
        updatedAt: Date,
        skipValidation: Bool
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
