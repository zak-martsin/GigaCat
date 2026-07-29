import Foundation

/// Bundles visible mini-player state with the routing context that produced it.
struct MiniPlayerPresentation {
    let state: MiniPlayerState
    let context: MiniPlayerContext
}

/// Repository-backed context used to resolve mini-player actions.
enum MiniPlayerContext {
    case noProgramSelected
    case readyToStart(workoutDayID: UUID)
    case activeSession(
        session: WorkoutSession,
        programTitle: String,
        workoutDayTitle: String,
        isExpired: Bool
    )
}

/// Presentation model for an expired workout session alert.
struct ExpiredSessionAlert: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
}

/// Navigation outcome requested by a mini-player interaction.
enum MiniPlayerRoute: Equatable {
    case none
    // FIXME: Carry workout context when the Workout flow supports direct routing.
    case openWorkout
}
