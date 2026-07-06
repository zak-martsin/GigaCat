import Foundation

/// Repository-level failures returned when requested records are missing or conflict with domain rules.
enum RepositoryError: LocalizedError, Equatable {
    case userNotFound
    case workoutProgramNotFound
    case workoutDayNotFound
    case exerciseNotFound
    case workoutSessionNotFound
    case activeSessionAlreadyExists
    case workoutSessionNotActive

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "The user could not be found."
        case .workoutProgramNotFound:
            return "The workout program could not be found."
        case .workoutDayNotFound:
            return "The workout day could not be found."
        case .exerciseNotFound:
            return "The exercise could not be found."
        case .workoutSessionNotFound:
            return "The workout session could not be found."
        case .activeSessionAlreadyExists:
            return "The user already has an active workout session."
        case .workoutSessionNotActive:
            return "The workout session is no longer active."
        }
    }
}
