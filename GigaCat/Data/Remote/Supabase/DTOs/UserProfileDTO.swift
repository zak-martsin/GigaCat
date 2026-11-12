import Foundation

/// Transport representation of one row in `public.profiles`.
struct UserProfileDTO: Codable, Equatable, Sendable {
    let id: UUID
    let selectedProgramID: UUID?
    let createdAt: Date
    let updatedAt: Date

    var goal: TrainingGoal?
    var level: TrainingLevel?
    var avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case selectedProgramID = "selected_program_id"
        case goal
        case level
        case avatarPath = "avatar_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Columns accepted when updating one row in `public.profiles`.
struct UpdateUserProfileDTO: Encodable, Equatable, Sendable {
    let selectedProgramID: UUID?
    var personalization: ProfilePersonalization?

    enum CodingKeys: String, CodingKey {
        case selectedProgramID = "selected_program_id"
        case goal
        case level
        case avatarPath = "avatar_path"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedProgramID, forKey: .selectedProgramID)
        if let personalization {
            try container.encode(personalization.goal, forKey: .goal)
            try container.encode(personalization.level, forKey: .level)
            try container.encode(personalization.avatarPath, forKey: .avatarPath)
        }
    }
}
