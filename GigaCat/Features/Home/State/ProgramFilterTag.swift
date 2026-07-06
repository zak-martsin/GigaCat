import Foundation

/// User-facing filter used by Home to switch between all programs and a specific training tag.
enum ProgramFilterTag: Identifiable, Hashable {
    case all
    case tag(WorkoutProgramTag)

    var id: String {
        switch self {
        case .all:
            "all"
        case let .tag(tag):
            tag.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case let .tag(tag):
            tag.title
        }
    }
}
