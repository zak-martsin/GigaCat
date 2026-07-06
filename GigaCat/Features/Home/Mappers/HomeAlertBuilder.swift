import Foundation

/// Creates the user-facing alert copy used by Home session flows.
protocol HomeAlertBuilding: Sendable {
    func makeExpiredSessionAlert(
        sessionID: UUID,
        programTitle: String,
        workoutDayTitle: String
    ) -> ExpiredSessionAlert

    func makeProgramSelectionConflictAlert(
        sessionID: UUID,
        currentProgramTitle: String,
        currentWorkoutDayTitle: String
    ) -> ProgramSelectionConflictAlert
}

/// Keeps Home alert wording centralized so copy can evolve without touching flow logic.
struct HomeAlertBuilder: HomeAlertBuilding {
    func makeExpiredSessionAlert(
        sessionID: UUID,
        programTitle: String,
        workoutDayTitle: String
    ) -> ExpiredSessionAlert {
        ExpiredSessionAlert(
            id: sessionID,
            title: "Session Timed Out",
            message: "Your \(programTitle) session on \(workoutDayTitle) has been inactive for a while. You can continue it, finish it, or discard it."
        )
    }

    func makeProgramSelectionConflictAlert(
        sessionID: UUID,
        currentProgramTitle: String,
        currentWorkoutDayTitle: String
    ) -> ProgramSelectionConflictAlert {
        ProgramSelectionConflictAlert(
            id: sessionID,
            title: "Unfinished Workout In Progress",
            message: "You already have an active workout session. Before switching programs, you need to either finish this session or cancel it. If you press Cancel, nothing will change and your current session will stay active.",
            currentProgramTitle: currentProgramTitle,
            currentWorkoutDayTitle: currentWorkoutDayTitle
        )
    }
}
