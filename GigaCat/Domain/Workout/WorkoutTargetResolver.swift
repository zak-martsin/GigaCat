/// Builds session recommendations without persistence, transport or presentation dependencies.
struct WorkoutTargetResolver: Sendable {
    func targets(exercises: [WorkoutDayExercise], user: User) -> [WorkoutExerciseTarget] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
            WorkoutExerciseTarget(
                workoutDayExerciseID: exercise.id,
                targetSets: TargetSetsPolicy().targetSets(
                    goal: user.goal, level: user.level, override: exercise.targetSets
                ),
                programOverride: exercise.targetSets
            )
        }
    }

    /// Re-evaluates every exercise, including those already logged, preserving program overrides.
    func recalculated(_ targets: [WorkoutExerciseTarget], user: User) -> [WorkoutExerciseTarget] {
        targets.map { target in
            WorkoutExerciseTarget(
                workoutDayExerciseID: target.workoutDayExerciseID,
                targetSets: TargetSetsPolicy().targetSets(
                    goal: user.goal, level: user.level, override: target.programOverride
                ),
                programOverride: target.programOverride
            )
        }
    }
}
