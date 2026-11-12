/// Gives a program override priority over profile recommendations, with two sets as the fallback.
struct TargetSetsPolicy: Sendable {
    static let defaultTargetSets = 2

    func targetSets(goal: TrainingGoal?, level: TrainingLevel?, override: Int? = nil) -> Int {
        if let override { return override }
        guard let goal, let level else { return Self.defaultTargetSets }
        switch (goal, level) {
        case (.loseWeight, .beginner), (.maintain, .beginner):
            return 2
        case (.buildMuscle, .beginner),
             (.loseWeight, .intermediate), (.loseWeight, .advanced),
             (.maintain, .intermediate), (.maintain, .advanced):
            return 3
        case (.buildMuscle, .intermediate), (.buildMuscle, .advanced):
            return 4
        }
    }
}
