import Foundation

/// User-facing catalog filter derived from tags present in the local default catalog.
enum CatalogFilter: Identifiable, Hashable {
    case all
    case tag(WorkoutProgramTag)

    var id: String {
        switch self {
        case .all:
            "all"
        case .tag(let tag):
            tag.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .tag(let tag):
            tag.title
        }
    }
}
