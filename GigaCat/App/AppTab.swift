import Foundation

enum AppTab: Hashable, CaseIterable {
    case home
    case progress
    case workout
    case nutrition
    case library

    var title: String {
        switch self {
        case .home:
            "Home"
        case .progress:
            "Progress"
        case .workout:
            "Workout"
        case .nutrition:
            "Nutrition"
        case .library:
            "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .progress:
            "chart.line.uptrend.xyaxis"
        case .workout:
            "dumbbell"
        case .nutrition:
            "leaf"
        case .library:
            "books.vertical"
        }
    }
}
