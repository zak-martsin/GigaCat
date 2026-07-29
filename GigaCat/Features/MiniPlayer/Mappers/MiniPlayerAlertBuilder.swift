import Foundation

protocol MiniPlayerAlertBuilding: Sendable {
    func makeExpiredSessionAlert(
        sessionID: UUID,
        programTitle: String,
        workoutDayTitle: String
    ) -> ExpiredSessionAlert
}

struct MiniPlayerAlertBuilder: MiniPlayerAlertBuilding {
    func makeExpiredSessionAlert(
        sessionID: UUID,
        programTitle: String,
        workoutDayTitle: String
    ) -> ExpiredSessionAlert {
        ExpiredSessionAlert(
            id: sessionID,
            title: "Session Timed Out",
            message: "Your \(programTitle) session on \(workoutDayTitle) " +
                "has been inactive for a while. You can continue it, finish it, or discard it."
        )
    }
}
