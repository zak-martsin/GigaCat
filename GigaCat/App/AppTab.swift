import Foundation

enum AppTab: Hashable, CaseIterable {
    case catalog
    case workout
    case progress

    var title: String {
        switch self {
        case .catalog:
            "Catalog"
        case .workout:
            "Workout"
        case .progress:
            "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .catalog:
            "square.grid.2x2"
        case .workout:
            "dumbbell"
        case .progress:
            "chart.line.uptrend.xyaxis"
        }
    }
}
