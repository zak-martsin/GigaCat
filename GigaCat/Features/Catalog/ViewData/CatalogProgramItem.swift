import Foundation

/// Compact presentation model for one default program in Catalog.
struct CatalogProgramItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let dayCount: Int
    let exerciseCount: Int
    let isSelected: Bool
    let tags: [WorkoutProgramTag]
}
