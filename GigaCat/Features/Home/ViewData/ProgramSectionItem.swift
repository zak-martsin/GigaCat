import Foundation

/// Compact card and row presentation model used by Home lists.
struct ProgramSectionItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let dayCount: Int
    let exerciseCount: Int
    let rateScore: Double?
    let isSelected: Bool
    let isRecommended: Bool
    let isPopular: Bool
    let tags: [WorkoutProgramTag]
}
