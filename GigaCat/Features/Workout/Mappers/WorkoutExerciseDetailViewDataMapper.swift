import Foundation

struct WorkoutExerciseLogContext {
    let savedLogsBySetNumber: [Int: ExerciseLog]
    let latestExerciseLog: ExerciseLog?
    let displayedSetCount: Int
    let setSaveState: WorkoutSetSaveState
}

/// Projects the selected planned exercise into data for the exercise detail screen.
struct WorkoutExerciseDetailViewDataMapper {
    func map(
        selectedExercise: WorkoutExerciseContent,
        selectedExerciseIndex: Int,
        totalCount: Int,
        logContext: WorkoutExerciseLogContext
    ) -> WorkoutExerciseDetailViewData {
        WorkoutExerciseDetailViewData(
            id: selectedExercise.dayExercise.id,
            name: selectedExercise.exercise.name,
            position: selectedExerciseIndex + 1,
            totalCount: totalCount,
            targetSummary: makeTargetSummary(from: selectedExercise.dayExercise),
            sets: makeSetRows(
                from: selectedExercise.dayExercise,
                logContext: logContext
            ),
            canGoBack: selectedExerciseIndex > 0,
            canGoForward: selectedExerciseIndex < totalCount - 1
        )
    }

    private func makeSetRows(
        from dayExercise: WorkoutDayExercise,
        logContext: WorkoutExerciseLogContext
    ) -> [WorkoutSetRowViewData] {
        let isSaveBlocked = logContext.setSaveState.isSaving

        return (0..<logContext.displayedSetCount).map { index in
            let setNumber = index + 1
            let savedLog = logContext.savedLogsBySetNumber[setNumber]
            let latestPriorLog = logContext.savedLogsBySetNumber
                .filter { $0.key < setNumber }
                .values
                .max(by: Self.isOlder)
            let suggestedWeight = latestPriorLog?.weight
                ?? logContext.latestExerciseLog?.weight
            let suggestedReps = latestPriorLog?.reps
                ?? dayExercise.targetReps

            return WorkoutSetRowViewData(
                setNumber: setNumber,
                savedRepsText: savedLog.map { String($0.reps) },
                savedWeightText: savedLog.map { formattedWeight($0.weight) },
                suggestedRepsPlaceholder: String(suggestedReps),
                suggestedWeightPlaceholder: suggestedWeight.map(formattedWeight),
                isSaved: savedLog != nil,
                isSaving: logContext.setSaveState == .saving(setNumber: setNumber),
                isSaveBlocked: isSaveBlocked
            )
        }
    }

    private func makeTargetSummary(from dayExercise: WorkoutDayExercise) -> String {
        let setUnit = dayExercise.targetSets == 1 ? "set" : "sets"
        let repUnit = dayExercise.targetReps == 1 ? "rep" : "reps"
        let components = [
            "\(dayExercise.targetSets) \(setUnit)",
            "\(dayExercise.targetReps) \(repUnit)"
        ]

        return components.joined(separator: " · ")
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func isOlder(_ lhs: ExerciseLog, _ rhs: ExerciseLog) -> Bool {
        if lhs.performedAt == rhs.performedAt {
            return lhs.setNumber < rhs.setNumber
        }

        return lhs.performedAt < rhs.performedAt
    }
}

private extension WorkoutSetSaveState {
    var isSaving: Bool {
        if case .saving = self {
            return true
        }

        return false
    }
}
