import Foundation
import Testing
@testable import GigaCat

struct WorkoutExerciseDetailViewDataMapperTests {

    @Test
    func mapsSelectedExerciseAndNavigationState() throws {
        let content = try makeExerciseContent(
            targetSets: 3,
            targetReps: 8
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 1,
            totalCount: 4,
            logContext: WorkoutExerciseLogContext(
                savedLogsBySetNumber: [:],
                latestExerciseLog: nil,
                displayedSetCount: 3,
                setSaveState: .ready
            )
        )

        #expect(viewData.id == content.dayExercise.id)
        #expect(viewData.name == content.exercise.name)
        #expect(viewData.position == 2)
        #expect(viewData.totalCount == 4)
        #expect(viewData.targetSummary == "3 sets · 8 reps")
        #expect(viewData.canGoBack)
        #expect(viewData.canGoForward)
    }

    @Test
    func latestExerciseLogSuggestsWeightWhileProgramSuggestsReps() throws {
        let content = try makeExerciseContent(
            targetSets: 3,
            targetReps: 8
        )
        let previousLog = try ExerciseLog(
            sessionId: UUID(),
            workoutDayExerciseId: UUID(),
            weight: 60,
            reps: 5,
            setNumber: 3
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 0,
            totalCount: 1,
            logContext: WorkoutExerciseLogContext(
                savedLogsBySetNumber: [:],
                latestExerciseLog: previousLog,
                displayedSetCount: 3,
                setSaveState: .ready
            )
        )

        #expect(
            viewData.sets == [
                WorkoutSetRowViewData(
                    setNumber: 1,
                    savedRepsText: nil,
                    savedWeightText: nil,
                    suggestedRepsPlaceholder: "8",
                    suggestedWeightPlaceholder: "60",
                    isSaved: false,
                    isSaving: false,
                    isSaveBlocked: false
                ),
                WorkoutSetRowViewData(
                    setNumber: 2,
                    savedRepsText: nil,
                    savedWeightText: nil,
                    suggestedRepsPlaceholder: "8",
                    suggestedWeightPlaceholder: "60",
                    isSaved: false,
                    isSaving: false,
                    isSaveBlocked: false
                ),
                WorkoutSetRowViewData(
                    setNumber: 3,
                    savedRepsText: nil,
                    savedWeightText: nil,
                    suggestedRepsPlaceholder: "8",
                    suggestedWeightPlaceholder: "60",
                    isSaved: false,
                    isSaving: false,
                    isSaveBlocked: false
                )
            ]
        )
    }

    @Test
    func savedSetBecomesSuggestionForFollowingSets() throws {
        let content = try makeExerciseContent(
            targetSets: 2,
            targetReps: 8
        )
        let savedLog = try ExerciseLog(
            sessionId: UUID(),
            workoutDayExerciseId: content.dayExercise.id,
            weight: 62.5,
            reps: 7,
            setNumber: 1
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 0,
            totalCount: 1,
            logContext: WorkoutExerciseLogContext(
                savedLogsBySetNumber: [1: savedLog],
                latestExerciseLog: nil,
                displayedSetCount: 2,
                setSaveState: .saving(setNumber: 2)
            )
        )

        #expect(
            viewData.sets == [
                WorkoutSetRowViewData(
                    setNumber: 1,
                    savedRepsText: "7",
                    savedWeightText: formattedWeight(62.5),
                    suggestedRepsPlaceholder: "8",
                    suggestedWeightPlaceholder: nil,
                    isSaved: true,
                    isSaving: false,
                    isSaveBlocked: true
                ),
                WorkoutSetRowViewData(
                    setNumber: 2,
                    savedRepsText: nil,
                    savedWeightText: nil,
                    suggestedRepsPlaceholder: "7",
                    suggestedWeightPlaceholder: formattedWeight(62.5),
                    isSaved: false,
                    isSaving: true,
                    isSaveBlocked: true
                )
            ]
        )
    }

    @Test
    func hasNoWeightSuggestionWithoutExerciseHistory() throws {
        let content = try makeExerciseContent(
            targetSets: 1,
            targetReps: 12
        )

        let viewData = WorkoutExerciseDetailViewDataMapper().map(
            selectedExercise: content,
            selectedExerciseIndex: 0,
            totalCount: 1,
            logContext: WorkoutExerciseLogContext(
                savedLogsBySetNumber: [:],
                latestExerciseLog: nil,
                displayedSetCount: 1,
                setSaveState: .ready
            )
        )

        #expect(viewData.sets == [
            WorkoutSetRowViewData(
                setNumber: 1,
                savedRepsText: nil,
                savedWeightText: nil,
                suggestedRepsPlaceholder: "12",
                suggestedWeightPlaceholder: nil,
                isSaved: false,
                isSaving: false,
                isSaveBlocked: false
            )
        ])
        #expect(viewData.targetSummary == "1 set · 12 reps")
    }
}

private extension WorkoutExerciseDetailViewDataMapperTests {
    func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }

    func makeExerciseContent(
        targetSets: Int,
        targetReps: Int
    ) throws -> WorkoutExerciseContent {
        let dayID = UUID()
        let exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
        let dayExercise = try WorkoutDayExercise(
            workoutDayId: dayID,
            exerciseId: exercise.id,
            targetSets: targetSets,
            targetReps: targetReps,
            orderIndex: 0
        )

        return WorkoutExerciseContent(
            dayExercise: dayExercise,
            exercise: exercise
        )
    }
}
