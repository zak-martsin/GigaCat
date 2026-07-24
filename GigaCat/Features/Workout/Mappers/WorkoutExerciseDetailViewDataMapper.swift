import Foundation

struct WorkoutExerciseLogContext {
    let savedLogsBySetNumber: [Int: ExerciseLog]
    let previousExerciseLog: ExerciseLog?
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
        (0..<logContext.displayedSetCount).map { index in
            let setNumber = index + 1
            let savedLog = logContext.savedLogsBySetNumber[setNumber]
            let previousCurrentLog = logContext.savedLogsBySetNumber.values
                .filter { $0.setNumber < setNumber }
                .max { $0.setNumber < $1.setNumber }
            let suggestedWeight = previousCurrentLog?.weight
                ?? logContext.previousExerciseLog?.weight
            let suggestedReps = previousCurrentLog?.reps
                ?? dayExercise.targetReps

            return WorkoutSetRowViewData(
                setNumber: setNumber,
                savedRepsText: savedLog.map { String($0.reps) },
                savedWeightText: savedLog.map { formattedWeight($0.weight) },
                suggestedRepsPlaceholder: String(suggestedReps),
                suggestedWeightPlaceholder: suggestedWeight.map(formattedWeight),
                isSaved: savedLog != nil,
                isSaving: logContext.setSaveState == .saving(setNumber: setNumber)
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
}
