import Foundation

/// User-facing training category that helps group and surface workout programs.
enum WorkoutProgramTag: String, Codable, CaseIterable, Sendable {
    case gym
    case home
    case streetWorkout
    case cardio
    case strength
    case muscleGain
    case mobility
    case hiit
    case bodyweight

    var title: String {
        switch self {
        case .gym:
            "Gym"
        case .home:
            "Home"
        case .streetWorkout:
            "Street Workout"
        case .cardio:
            "Cardio"
        case .strength:
            "Strength"
        case .muscleGain:
            "Muscle Gain"
        case .mobility:
            "Stretching"
        case .hiit:
            "HIIT"
        case .bodyweight:
            "Bodyweight"
        }
    }
}
