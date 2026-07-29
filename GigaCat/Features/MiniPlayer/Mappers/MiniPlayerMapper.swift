import Foundation

protocol MiniPlayerMapping: Sendable {
    func mapActiveSession(
        _ session: WorkoutSession,
        programTitle: String,
        workoutDayTitle: String,
        completionPercentage: Int,
        isExpired: Bool
    ) -> MiniPlayerPresentation
    func mapNoProgramSelected() -> MiniPlayerPresentation
    func mapProgramWithoutDays(title: String) -> MiniPlayerPresentation
    func mapReadyToStart(
        programTitle: String,
        workoutDayID: UUID,
        workoutDayTitle: String
    ) -> MiniPlayerPresentation
}

struct MiniPlayerMapper: MiniPlayerMapping {
    func mapActiveSession(
        _ session: WorkoutSession,
        programTitle: String,
        workoutDayTitle: String,
        completionPercentage: Int,
        isExpired: Bool
    ) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: programTitle,
                subtitle: "\(workoutDayTitle) • \(completionPercentage)% completed",
                action: .continueWorkout
            ),
            context: .activeSession(
                session: session,
                programTitle: programTitle,
                workoutDayTitle: workoutDayTitle,
                isExpired: isExpired
            )
        )
    }

    func mapNoProgramSelected() -> MiniPlayerPresentation {
        MiniPlayerPresentation(state: .empty, context: .noProgramSelected)
    }

    func mapProgramWithoutDays(title: String) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: title,
                subtitle: "This program has no workout days yet.",
                action: .none
            ),
            context: .noProgramSelected
        )
    }

    func mapReadyToStart(
        programTitle: String,
        workoutDayID: UUID,
        workoutDayTitle: String
    ) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: programTitle,
                subtitle: "Next workout: \(workoutDayTitle)",
                action: .start
            ),
            context: .readyToStart(workoutDayID: workoutDayID)
        )
    }
}
