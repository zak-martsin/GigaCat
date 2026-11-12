/// The user's optional training objective, independent of profile completion.
enum TrainingGoal: String, Codable, CaseIterable, Sendable {
    case loseWeight
    case maintain
    case buildMuscle
}
