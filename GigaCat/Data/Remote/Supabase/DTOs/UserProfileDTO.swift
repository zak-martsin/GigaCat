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
