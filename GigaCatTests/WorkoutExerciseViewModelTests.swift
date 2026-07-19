import Foundation
import Testing
@testable import GigaCat

@MainActor
struct WorkoutExerciseViewModelTests {

    @Test
    func selectsRequestedExerciseAfterOrderingDayContent() throws {
        let fixture = try Fixture()
        let viewModel = WorkoutExerciseViewModel(
            dayContent: fixture.dayContent,
            initialDayExerciseID: fixture.second.dayExercise.id
        )

        #expect(viewModel.day == fixture.dayContent.day)
        #expect(viewModel.exercises.map(\.dayExercise.orderIndex) == [0, 1, 2])
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)
        #expect(viewModel.selectedExercise == fixture.second)
        #expect(viewModel.selectedExerciseIndex == 1)
        #expect(viewModel.canSelectPreviousExercise)
        #expect(viewModel.canSelectNextExercise)
    }

    @Test
    func selectsPreviousAndNextExercisesWithinDayBounds() throws {
        let fixture = try Fixture()
        let viewModel = WorkoutExerciseViewModel(
            dayContent: fixture.dayContent,
            initialDayExerciseID: fixture.first.dayExercise.id
        )

        viewModel.selectPreviousExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.first.dayExercise.id)
        #expect(!viewModel.canSelectPreviousExercise)

        viewModel.selectNextExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)

        viewModel.selectNextExercise()
        viewModel.selectNextExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.third.dayExercise.id)
        #expect(!viewModel.canSelectNextExercise)

        viewModel.selectPreviousExercise()
        #expect(viewModel.selectedDayExerciseID == fixture.second.dayExercise.id)
    }

    @Test
    func fallsBackToFirstExerciseWhenInitialIDIsOutsideDay() throws {
        let fixture = try Fixture()
        let viewModel = WorkoutExerciseViewModel(
            dayContent: fixture.dayContent,
            initialDayExerciseID: UUID()
        )

        #expect(viewModel.selectedDayExerciseID == fixture.first.dayExercise.id)
        #expect(viewModel.selectedExerciseIndex == 0)
    }

    @Test
    func emptyDayHasNoExerciseSelection() throws {
        let fixture = try Fixture()
        let viewModel = WorkoutExerciseViewModel(
            dayContent: WorkoutDayContent(day: fixture.dayContent.day, exercises: []),
            initialDayExerciseID: UUID()
        )

        #expect(viewModel.selectedDayExerciseID == nil)
        #expect(viewModel.selectedExercise == nil)
        #expect(viewModel.selectedExerciseIndex == nil)
        #expect(!viewModel.canSelectPreviousExercise)
        #expect(!viewModel.canSelectNextExercise)
    }
}

private extension WorkoutExerciseViewModelTests {
    struct Fixture {
        let first: WorkoutExerciseContent
        let second: WorkoutExerciseContent
        let third: WorkoutExerciseContent
        let dayContent: WorkoutDayContent

        init() throws {
            let programID = UUID()
            let day = try WorkoutDay(
                programId: programID,
                title: "Strength Day",
                orderIndex: 0
            )
            let first = try Self.makeExerciseContent(
                name: "Bench Press",
                dayID: day.id,
                orderIndex: 0
            )
            let second = try Self.makeExerciseContent(
                name: "Incline Press",
                dayID: day.id,
                orderIndex: 1
            )
            let third = try Self.makeExerciseContent(
                name: "Chest Fly",
                dayID: day.id,
                orderIndex: 2
            )

            self.first = first
            self.second = second
            self.third = third
            dayContent = WorkoutDayContent(
                day: day,
                exercises: [third, first, second]
            )
        }

        private static func makeExerciseContent(
            name: String,
            dayID: UUID,
            orderIndex: Int
        ) throws -> WorkoutExerciseContent {
            let exercise = try Exercise(name: name, muscleGroup: .chest)
            let dayExercise = try WorkoutDayExercise(
                workoutDayId: dayID,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                targetWeight: 60,
                orderIndex: orderIndex
            )

            return WorkoutExerciseContent(
                dayExercise: dayExercise,
                exercise: exercise
            )
        }
    }
}
