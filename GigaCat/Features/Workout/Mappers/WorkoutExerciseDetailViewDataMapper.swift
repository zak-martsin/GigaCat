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
}
