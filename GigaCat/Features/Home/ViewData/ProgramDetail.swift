import Foundation

/// Full program presentation model used by the Home detail sheet.
struct ProgramDetail: Identifiable, Equatable {
    /// Primary CTA shown in the detail sheet for the current Home state.
    enum PrimaryAction: Equatable {
        case chooseProgram
        case startWorkout
        case continueWorkout

        var title: String {
            switch self {
            case .chooseProgram:
                "Choose Program"
            case .startWorkout:
                "Start"
            case .continueWorkout:
                "Continue"
            }
        }
    }

    let id: UUID
    let title: String
    let description: String
    let dayCount: Int
    let exerciseCount: Int
    let rateScore: Double?
    let isSelected: Bool
    let primaryAction: PrimaryAction
    let progressText: String?
    let hasActiveSession: Bool
    let tags: [WorkoutProgramTag]
    let workoutDayTitles: [String]
}
