import Foundation

struct WorkoutExerciseDetailViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let position: Int
    let totalCount: Int
    let targetSummary: String
    let sets: [WorkoutSetRowViewData]
    let canGoBack: Bool
    let canGoForward: Bool
}

struct WorkoutSetRowViewData: Identifiable, Equatable, Sendable {
    var id: Int { setNumber }

    let setNumber: Int
    let savedRepsText: String?
    let savedWeightText: String?
    let suggestedRepsPlaceholder: String
    let suggestedWeightPlaceholder: String?
    let isSaved: Bool
    let isSaving: Bool
    let isSaveBlocked: Bool
}
