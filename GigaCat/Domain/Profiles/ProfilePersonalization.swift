/// A complete replacement of optional profile fields. A nil value explicitly clears a field.
/// A missing personalization value in a mutation leaves all three fields unchanged.
struct ProfilePersonalization: Codable, Equatable, Sendable {
    let goal: TrainingGoal?
    let level: TrainingLevel?
    let avatarPath: String?
}
