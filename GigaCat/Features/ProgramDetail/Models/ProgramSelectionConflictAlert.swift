import Foundation

/// Presentation state shown when selecting a program would replace an unfinished workout.
struct ProgramSelectionConflictAlert: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let currentProgramTitle: String
    let currentWorkoutDayTitle: String
}
