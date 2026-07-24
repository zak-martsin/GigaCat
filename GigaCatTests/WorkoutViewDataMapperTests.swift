import Foundation
import Testing
@testable import GigaCat

struct WorkoutViewDataMapperTests {

    @Test
    func mapsProgramAndDaySelectionState() throws {
        let fixture = try Fixture()

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.programTitle == fixture.context.program.title)
        #expect(
            viewData?.sessionStatus == WorkoutSessionStatusViewData(
                title: "Workout in progress",
                isInProgress: true
            )
        )
        #expect(
            viewData?.days == [
                WorkoutDayItemViewData(
                    id: fixture.firstDay.id,
                    title: "Day 1",
                    isSelected: true,
                    hasActiveSession: false
                ),
                WorkoutDayItemViewData(
                    id: fixture.secondDay.id,
                    title: "Day 2",
                    isSelected: false,
                    hasActiveSession: true
                )
            ]
        )
    }

    @Test
    func mapsReadyStatusWhenSessionIsNotActive() throws {
        let fixture = try Fixture()
        let context = WorkoutContext(
            userID: fixture.context.userID,
            program: fixture.context.program,
            dayContents: fixture.context.dayContents,
            initialDayID: fixture.context.initialDayID,
            activeSession: nil
        )

        let viewData = WorkoutViewDataMapper().map(
            context: context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(
            viewData?.sessionStatus == WorkoutSessionStatusViewData(
                title: "Ready to start",
                isInProgress: false
            )
        )
    }

    @Test
    func mapsSelectedDayExercisesWithNumericTargets() throws {
        let fixture = try Fixture()

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.id == fixture.firstDay.id)
        #expect(
            viewData?.selectedDay.exercises == [
                WorkoutExerciseViewData(
                    id: fixture.dayExercise.id,
                    name: fixture.exercise.name,
                    targetSets: 4,
                    targetReps: 6
                )
            ]
        )
    }

    @Test
    func returnsNilForDayOutsideContext() throws {
        let fixture = try Fixture()

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: UUID()
        )

        #expect(viewData == nil)
    }
}

private extension WorkoutViewDataMapperTests {
    struct Fixture {
        let firstDay: WorkoutDay
        let secondDay: WorkoutDay
        let exercise: Exercise
        let dayExercise: WorkoutDayExercise
        let context: WorkoutContext

        init() throws {
            let program = try WorkoutProgram(
                title: "Strength Program",
                description: "A focused strength program."
            )
            firstDay = try WorkoutDay(
                programId: program.id,
                title: "Push",
                orderIndex: 0
            )
            secondDay = try WorkoutDay(
                programId: program.id,
                title: "Pull",
                orderIndex: 1
            )
            exercise = try Exercise(
                name: "Deadlift",
                muscleGroup: .fullBody
            )
            dayExercise = try WorkoutDayExercise(
                workoutDayId: firstDay.id,
                exerciseId: exercise.id,
                targetSets: 4,
                targetReps: 6,
                orderIndex: 0
            )
            let activeSession = try WorkoutSession(
                userId: UUID(),
                workoutDayId: secondDay.id
            )
            context = WorkoutContext(
                userID: activeSession.userId,
                program: program,
                dayContents: [
                    WorkoutDayContent(
                        day: firstDay,
                        exercises: [
                            WorkoutExerciseContent(
                                dayExercise: dayExercise,
                                exercise: exercise
                            )
                        ]
                    ),
                    WorkoutDayContent(day: secondDay, exercises: [])
                ],
                initialDayID: firstDay.id,
                activeSession: activeSession
            )
        }
    }
}
