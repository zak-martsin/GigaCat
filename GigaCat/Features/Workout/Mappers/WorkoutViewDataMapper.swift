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
            sessionStatus: mapSessionStatus(activeSession: context.activeSession),
            days: context.dayContents.map { content in
                WorkoutDayItemViewData(
                    id: content.day.id,
                    title: "Day \(content.day.orderIndex + 1)",
                    isSelected: content.day.id == selectedDayID,
                    hasActiveSession: content.day.id == context.activeSession?.workoutDayId
                )
            },
            selectedDay: SelectedWorkoutDayViewData(
                id: selectedDayContent.day.id,
                exercises: selectedDayContent.exercises.map(mapExercise)
            )
        )
    }

    private func mapSessionStatus(
        activeSession: WorkoutSession?
    ) -> WorkoutSessionStatusViewData {
        guard activeSession != nil else {
            return WorkoutSessionStatusViewData(
                title: "Ready to start",
                isInProgress: false
            )
        }

        return WorkoutSessionStatusViewData(
            title: "Workout in progress",
            isInProgress: true
        )
    }

    private func mapExercise(_ content: WorkoutExerciseContent) -> WorkoutExerciseViewData {
        WorkoutExerciseViewData(
            id: content.dayExercise.id,
            name: content.exercise.name,
            targetSets: content.dayExercise.targetSets,
            targetReps: content.dayExercise.targetReps
        )
    }
}
