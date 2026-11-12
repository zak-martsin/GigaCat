/// The user's self-selected training experience used for workload recommendations.
enum TrainingLevel: String, Codable, CaseIterable, Sendable {
    case beginner
    case intermediate
    case advanced
}
