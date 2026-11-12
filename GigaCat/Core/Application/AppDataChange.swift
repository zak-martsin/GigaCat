/// Describes a successful source-of-truth mutation without naming the screens affected by it.
enum AppDataChange: Equatable, Sendable {
    case selectedProgram
    case workoutSession
    case programCatalog
    case remoteProfile
    case trainingPreferences
}

typealias AppDataChangeHandler = @MainActor (AppDataChange) async -> Void
