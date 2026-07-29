import Foundation

/// Presentation model for an expired workout session alert shown from Home.
struct ExpiredSessionAlert: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
}

/// High-level navigation outcome requested by Home interactions.
enum MiniPlayerRoute: Equatable {
    case none
    // FIXME: Once Workout flow is implemented, this route should carry workout context
    // such as the selected workout day or active session instead of only switching tabs.
    case openWorkout
}
