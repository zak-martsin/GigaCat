import Foundation
import Observation

@MainActor
@Observable
final class WorkoutExerciseViewModel {
    let day: WorkoutDay
    let exercises: [WorkoutExerciseContent]
    private(set) var selectedDayExerciseID: UUID?

    init(
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID
    ) {
        let orderedExercises = dayContent.exercises.sorted {
            $0.dayExercise.orderIndex < $1.dayExercise.orderIndex
        }

        day = dayContent.day
        exercises = orderedExercises
        selectedDayExerciseID = orderedExercises.contains {
            $0.dayExercise.id == initialDayExerciseID
        } ? initialDayExerciseID : orderedExercises.first?.dayExercise.id
    }

    var selectedExercise: WorkoutExerciseContent? {
        guard let selectedDayExerciseID else { return nil }
        return exercises.first { $0.dayExercise.id == selectedDayExerciseID }
    }

    var selectedExerciseIndex: Int? {
        guard let selectedDayExerciseID else { return nil }
        return exercises.firstIndex { $0.dayExercise.id == selectedDayExerciseID }
    }

    var canSelectPreviousExercise: Bool {
        guard let selectedExerciseIndex else { return false }
        return selectedExerciseIndex > exercises.startIndex
    }

    var canSelectNextExercise: Bool {
        guard let selectedExerciseIndex else { return false }
        return selectedExerciseIndex < exercises.index(before: exercises.endIndex)
    }

    func selectPreviousExercise() {
        guard let selectedExerciseIndex, canSelectPreviousExercise else { return }
        selectedDayExerciseID = exercises[selectedExerciseIndex - 1].dayExercise.id
    }

    func selectNextExercise() {
        guard let selectedExerciseIndex, canSelectNextExercise else { return }
        selectedDayExerciseID = exercises[selectedExerciseIndex + 1].dayExercise.id
    }
}
