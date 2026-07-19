import Foundation

/// Projects the loaded workout domain context into immutable screen presentation data.
struct WorkoutViewDataMapper {
    func map(
        context: WorkoutContext,
        selectedDayID: UUID
    ) -> WorkoutViewData? {
        guard let selectedDayContent = context.dayContents.first(
            where: { $0.day.id == selectedDayID }
        ) else {
            return nil
        }

        return WorkoutViewData(
            programTitle: context.program.title,
            programDescription: context.program.description,
            days: context.dayContents.map { content in
                WorkoutDayItemViewData(
                    id: content.day.id,
                    title: content.day.title,
                    isSelected: content.day.id == selectedDayID,
                    hasActiveSession: content.day.id == context.activeSession?.workoutDayId
                )
            },
            selectedDay: SelectedWorkoutDayViewData(
                id: selectedDayContent.day.id,
                title: selectedDayContent.day.title,
                exercises: selectedDayContent.exercises.map(mapExercise)
            )
        )
    }

    private func mapExercise(_ content: WorkoutExerciseContent) -> WorkoutExerciseViewData {
        WorkoutExerciseViewData(
            id: content.dayExercise.id,
            name: content.exercise.name,
            muscleGroup: muscleGroupTitle(content.exercise.muscleGroup),
            targetSets: content.dayExercise.targetSets,
            targetReps: content.dayExercise.targetReps,
            targetWeight: content.dayExercise.targetWeight
        )
    }

    private func muscleGroupTitle(_ muscleGroup: ExerciseMuscleGroup) -> String {
        switch muscleGroup {
        case .fullBody:
            "Full Body"
        default:
            muscleGroup.rawValue.capitalized
        }
    }
}
