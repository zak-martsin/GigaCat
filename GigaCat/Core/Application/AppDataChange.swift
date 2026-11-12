/// Describes a successful source-of-truth mutation without naming the screens affected by it.
enum AppDataChange: Equatable, Sendable {
    case selectedProgram
    case workoutSession
    case programCatalog
    case remoteProfile
}

typealias AppDataChangeHandler = @MainActor (AppDataChange) async -> Void
