import Foundation

/// Summary of the currently selected program shown by Home outside the full detail sheet.
struct SelectedProgramSummary: Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let nextWorkoutTitle: String?
    let progressText: String?
}
