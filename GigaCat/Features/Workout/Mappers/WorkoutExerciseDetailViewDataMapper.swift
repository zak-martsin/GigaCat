import Foundation

/// Projects the selected planned exercise into data for the exercise detail screen.
struct WorkoutExerciseDetailViewDataMapper {
    func map(
        selectedExercise: WorkoutExerciseContent,
        selectedExerciseIndex: Int,
        totalCount: Int,
        canGoBack: Bool,
        canGoForward: Bool
    ) -> WorkoutExerciseDetailViewData {
        WorkoutExerciseDetailViewData(
            id: selectedExercise.dayExercise.id,
            name: selectedExercise.exercise.name,
            position: selectedExerciseIndex + 1,
            totalCount: totalCount,
            targetSummary: makeTargetSummary(from: selectedExercise.dayExercise),
            sets: makeSetTargets(from: selectedExercise.dayExercise),
            canGoBack: canGoBack,
            canGoForward: canGoForward
        )
    }

    private func makeSetTargets(
        from dayExercise: WorkoutDayExercise
    ) -> [WorkoutSetTargetViewData] {
        (0..<dayExercise.targetSets).map { index in
            WorkoutSetTargetViewData(
                setNumber: index + 1,
                targetReps: dayExercise.targetReps,
                targetWeight: dayExercise.targetWeight
            )
        }
    }

    private func makeTargetSummary(from dayExercise: WorkoutDayExercise) -> String {
        let setUnit = dayExercise.targetSets == 1 ? "set" : "sets"
        let repUnit = dayExercise.targetReps == 1 ? "rep" : "reps"
        var components = [
            "\(dayExercise.targetSets) \(setUnit)",
            "\(dayExercise.targetReps) \(repUnit)"
        ]

        if let targetWeight = dayExercise.targetWeight {
            components.append("\(formattedWeight(targetWeight)) kg")
        }

        return components.joined(separator: " · ")
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
}
