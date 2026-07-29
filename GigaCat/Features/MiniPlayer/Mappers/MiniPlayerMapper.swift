import Foundation

protocol MiniPlayerMapping: Sendable {
    func mapActiveSession(_ input: ActiveMiniPlayerPresentation) -> MiniPlayerPresentation
    func mapNoProgramSelected() -> MiniPlayerPresentation
    func mapProgramWithoutDays(id: UUID, title: String) -> MiniPlayerPresentation
    func mapReadyToStart(
        programID: UUID,
        programTitle: String,
        workoutDayID: UUID,
        workoutDayTitle: String
    ) -> MiniPlayerPresentation
}

struct MiniPlayerMapper: MiniPlayerMapping {
    func mapActiveSession(_ input: ActiveMiniPlayerPresentation) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: input.programTitle,
                subtitle: "\(input.workoutDayTitle) • \(input.completionPercentage)% completed",
                action: .continueWorkout
            ),
            context: .activeSession(
                session: input.session,
                programTitle: input.programTitle,
                workoutDayTitle: input.workoutDayTitle,
                isExpired: input.isExpired
            ),
            programID: input.programID
        )
    }

    func mapNoProgramSelected() -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: .empty,
            context: .noProgramSelected,
            programID: nil
        )
    }

    func mapProgramWithoutDays(id: UUID, title: String) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: title,
                subtitle: "This program has no workout days yet.",
                action: .none
            ),
            context: .noProgramSelected,
            programID: id
        )
    }

    func mapReadyToStart(
        programID: UUID,
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
            context: .readyToStart(workoutDayID: workoutDayID),
            programID: programID
        )
    }
}
