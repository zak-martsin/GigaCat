import Foundation
import Testing
@testable import GigaCat

struct WorkoutExerciseDetailViewDataMapperTests {

    @Test
    func mapsSelectedExerciseAndNavigationState() throws {
        let content = try makeExerciseContent(
            targetSets: 3,
            targetReps: 8,
            targetWeight: 60
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 1,
            totalCount: 4,
            canGoBack: true,
            canGoForward: true
        )

        #expect(viewData.id == content.dayExercise.id)
        #expect(viewData.name == content.exercise.name)
        #expect(viewData.position == 2)
        #expect(viewData.totalCount == 4)
        #expect(viewData.targetSummary == "3 sets · 8 reps · 60 kg")
        #expect(viewData.canGoBack)
        #expect(viewData.canGoForward)
    }

    @Test
    func createsOneTargetRowForEachPlannedSet() throws {
        let content = try makeExerciseContent(
            targetSets: 3,
            targetReps: 8,
            targetWeight: 60
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 0,
            totalCount: 1,
            canGoBack: false,
            canGoForward: false
        )

        #expect(
            viewData.sets == [
                WorkoutSetTargetViewData(setNumber: 1, targetReps: 8, targetWeight: 60),
                WorkoutSetTargetViewData(setNumber: 2, targetReps: 8, targetWeight: 60),
                WorkoutSetTargetViewData(setNumber: 3, targetReps: 8, targetWeight: 60)
            ]
        )
    }

    @Test
    func preservesMissingTargetWeight() throws {
        let content = try makeExerciseContent(
            targetSets: 1,
            targetReps: 12,
            targetWeight: nil
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 0,
            totalCount: 1,
            canGoBack: false,
            canGoForward: false
        )

        #expect(viewData.sets == [
            WorkoutSetTargetViewData(setNumber: 1, targetReps: 12, targetWeight: nil)
        ])
        #expect(viewData.targetSummary == "1 set · 12 reps")
    }
}

private extension WorkoutExerciseDetailViewDataMapperTests {
    func makeExerciseContent(
        targetSets: Int,
        targetReps: Int,
        targetWeight: Double?
    ) throws -> WorkoutExerciseContent {
        let dayID = UUID()
        let exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
        let dayExercise = try WorkoutDayExercise(
            workoutDayId: dayID,
            exerciseId: exercise.id,
            targetSets: targetSets,
            targetReps: targetReps,
            targetWeight: targetWeight,
            orderIndex: 0
        )

        return WorkoutExerciseContent(
            dayExercise: dayExercise,
            exercise: exercise
        )
    }
}
