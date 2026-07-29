import Foundation

/// UI state rendered by the app-level workout mini player.
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

    static let empty = MiniPlayerState(
        title: "No Program Selected",
        subtitle: "Choose a program to start training.",
        action: .none
    )
}
