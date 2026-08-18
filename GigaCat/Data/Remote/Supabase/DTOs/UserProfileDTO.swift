import Foundation

/// Transport representation of one row in `public.profiles`.
struct UserProfileDTO: Codable, Equatable, Sendable {
    let id: UUID
    let selectedProgramID: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case selectedProgramID = "selected_program_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Columns accepted when updating one row in `public.profiles`.
struct UpdateUserProfileDTO: Encodable, Equatable, Sendable {
    let selectedProgramID: UUID?

    enum CodingKeys: String, CodingKey {
        case selectedProgramID = "selected_program_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedProgramID, forKey: .selectedProgramID)
    }
}
