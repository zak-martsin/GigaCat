import Foundation

/// UI state rendered by the mini player shown from Home.
struct MiniPlayerState: Equatable {
    /// Describes the primary action currently available from the mini player.
    enum Action: Equatable {
        case none
        case start
        case continueWorkout
    }

    let title: String
    let subtitle: String
    let action: Action
}
