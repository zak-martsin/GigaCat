import Foundation

struct WorkoutExerciseDetailViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let position: Int
    let totalCount: Int
    let targetSummary: String
    let sets: [WorkoutSetTargetViewData]
    let canGoBack: Bool
    let canGoForward: Bool
}

struct WorkoutSetTargetViewData: Identifiable, Equatable, Sendable {
    var id: Int { setNumber }

    let setNumber: Int
    let targetReps: Int
    let targetWeight: Double?
}
