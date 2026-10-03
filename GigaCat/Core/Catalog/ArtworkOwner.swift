import Foundation

/// Identifies the catalog record and namespace that owns an artwork file.
enum ArtworkOwner: Hashable, Sendable {
    case program(UUID)
    case exercise(UUID)

    var id: UUID {
        switch self {
        case .program(let id), .exercise(let id):
            id
        }
    }
}
