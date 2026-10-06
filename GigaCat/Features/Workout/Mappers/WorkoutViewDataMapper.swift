import Foundation

/// Projects the loaded workout domain context into immutable screen presentation data.
struct WorkoutViewDataMapper {
    func map(
        context: WorkoutContext,
        selectedDayID: UUID,
        exerciseSetCounts: [UUID: Int] = [:],
        artworkFileURLs: [UUID: URL] = [:]
    ) -> WorkoutViewData? {
        guard let selectedDayContent = context.dayContents.first(
            where: { $0.day.id == selectedDayID }
        ) else {
            return nil
        }
        let completedSetCounts = mapCompletedSetCounts(
            context: context,
            selectedDayID: selectedDayID
        )
        let setCounts = mapSetCounts(
            context: context,
            selectedDayContent: selectedDayContent,
            exerciseSetCounts: exerciseSetCounts
        )

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
                exercises: selectedDayContent.exercises.map { content in
                    mapExercise(
                        content,
                        completedSets: completedSetCounts.map {
                            $0[content.dayExercise.id, default: 0]
                        },
                        setCount: setCounts[content.dayExercise.id],
                        artworkFileURLs: artworkFileURLs
                    )
                }
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

    private func mapExercise(
        _ content: WorkoutExerciseContent,
        completedSets: Int?,
        setCount: Int?,
        artworkFileURLs: [UUID: URL]
    ) -> WorkoutExerciseViewData {
        WorkoutExerciseViewData(
            id: content.dayExercise.id,
            exerciseID: content.exercise.id,
            name: content.exercise.name,
            completedSets: completedSets,
            setCount: setCount,
            targetReps: content.dayExercise.targetReps,
            artwork: content.exercise.artwork,
            artworkFileURL: artworkFileURLs[content.exercise.id]
        )
    }

    private func mapCompletedSetCounts(
        context: WorkoutContext,
        selectedDayID: UUID
    ) -> [UUID: Int]? {
        guard context.activeSession?.workoutDayId == selectedDayID else {
            return nil
        }

        return Dictionary(
            grouping: context.activeSessionLogs,
            by: \.workoutDayExerciseId
        )
        .mapValues(\.count)
    }

    private func mapSetCounts(
        context: WorkoutContext,
        selectedDayContent: WorkoutDayContent,
        exerciseSetCounts: [UUID: Int]
    ) -> [UUID: Int] {
        let isActiveDay = context.activeSession?.workoutDayId == selectedDayContent.day.id
        let highestSavedSetNumbers: [UUID: Int] = isActiveDay
            ? Dictionary(grouping: context.activeSessionLogs, by: \.workoutDayExerciseId)
                .mapValues { $0.map(\.setNumber).max() ?? 0 }
            : [:]
        var result: [UUID: Int] = [:]

        for content in selectedDayContent.exercises {
            let dayExerciseID = content.dayExercise.id
            let setCount = [
                content.dayExercise.targetSets,
                exerciseSetCounts[dayExerciseID],
                highestSavedSetNumbers[dayExerciseID]
            ]
            .compactMap { $0 }
            .max()

            if let setCount {
                result[dayExerciseID] = setCount
            }
        }

        return result
    }
}
