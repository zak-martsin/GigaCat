import Foundation

/// Lightweight progress summary used when Home needs to reference the currently active workout day.
struct ActiveSessionProgressState {
    let workoutDayTitle: String
    let progressText: String
}

/// Bundles user-visible mini player state with the internal routing context that produced it.
struct MiniPlayerPresentation {
    let state: MiniPlayerState
    let context: MiniPlayerContext
}

/// Internal Home state used to decide how the mini player and program actions should behave.
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
