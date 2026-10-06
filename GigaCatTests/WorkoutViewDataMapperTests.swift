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
            activeSession: nil,
            activeSessionLogs: []
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
                    exerciseID: fixture.exercise.id,
                    name: fixture.exercise.name,
                    completedSets: nil,
                    setCount: 4,
                    targetReps: 6,
                    artwork: nil,
                    artworkFileURL: nil
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

    @Test
    func mapsExerciseArtworkMetadataAndResolvedURL() throws {
        let fixture = try Fixture(hasArtwork: true)
        let fileURL = URL(filePath: "/tmp/deadlift.png")

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id,
            artworkFileURLs: [fixture.exercise.id: fileURL]
        )
        let exercise = try #require(viewData?.selectedDay.exercises.first)

        #expect(exercise.artwork == fixture.exercise.artwork)
        #expect(exercise.artworkFileURL == fileURL)
        #expect(exercise.artworkLoadIdentifier?.exerciseID == fixture.exercise.id)
    }

    @Test
    func mapsCompletedSetCountForExerciseInActiveDay() throws {
        let fixture = try Fixture(
            activeDayIndex: 0,
            completedSetNumbers: [1, 2]
        )

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.exercises.first?.completedSets == 2)
        #expect(viewData?.selectedDay.exercises.first?.setCount == 4)
    }

    @Test
    func mapsZeroCompletedSetsForUnstartedExerciseInActiveDay() throws {
        let fixture = try Fixture(activeDayIndex: 0)

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.exercises.first?.completedSets == 0)
    }

    @Test
    func omitsCompletedSetsOutsideActiveDay() throws {
        let fixture = try Fixture(
            activeDayIndex: 1,
            completedSetNumbers: [1]
        )

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.exercises.first?.completedSets == nil)
    }

    @Test
    func omitsCompletedSetsWithoutActiveSession() throws {
        let fixture = try Fixture(activeDayIndex: nil)

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.exercises.first?.completedSets == nil)
        #expect(viewData?.selectedDay.exercises.first?.setCount == 4)
    }

    @Test
    func addedSetCountBecomesDisplayedAndProgressSetCount() throws {
        let fixture = try Fixture(
            activeDayIndex: 0,
            completedSetNumbers: [1, 2]
        )

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id,
            exerciseSetCounts: [fixture.dayExercise.id: 5]
        )
        let exercise = try #require(viewData?.selectedDay.exercises.first)

        #expect(exercise.completedSets == 2)
        #expect(exercise.setCount == 5)
    }

    @Test
    func savedSetBeyondTargetRestoresSetCount() throws {
        let fixture = try Fixture(
            activeDayIndex: 0,
            completedSetNumbers: [1, 2, 3, 4, 5]
        )

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id
        )

        #expect(viewData?.selectedDay.exercises.first?.completedSets == 5)
        #expect(viewData?.selectedDay.exercises.first?.setCount == 5)
    }

    @Test
    func addedSetCountIsDisplayedBeforeSessionStarts() throws {
        let fixture = try Fixture(activeDayIndex: nil)

        let viewData = WorkoutViewDataMapper().map(
            context: fixture.context,
            selectedDayID: fixture.firstDay.id,
            exerciseSetCounts: [fixture.dayExercise.id: 5]
        )
        let exercise = try #require(viewData?.selectedDay.exercises.first)

        #expect(exercise.completedSets == nil)
        #expect(exercise.setCount == 5)
    }
}

private extension WorkoutViewDataMapperTests {
    struct Fixture {
        let firstDay: WorkoutDay
        let secondDay: WorkoutDay
        let exercise: Exercise
        let dayExercise: WorkoutDayExercise
        let context: WorkoutContext

        init(
            hasArtwork: Bool = false,
            activeDayIndex: Int? = 1,
            completedSetNumbers: [Int] = []
        ) throws {
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
                muscleGroup: .fullBody,
                artwork: hasArtwork
                    ? ArtworkReference(path: "exercise/main.png", revision: 1)
                    : nil
            )
            dayExercise = try WorkoutDayExercise(
                workoutDayId: firstDay.id,
                exerciseId: exercise.id,
                targetSets: 4,
                targetReps: 6,
                orderIndex: 0
            )
            let userID = UUID()
            let activeWorkout = try Self.makeActiveWorkout(
                userID: userID,
                days: [firstDay, secondDay],
                dayExerciseID: dayExercise.id,
                activeDayIndex: activeDayIndex,
                completedSetNumbers: completedSetNumbers
            )
            context = WorkoutContext(
                userID: userID,
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
                activeSession: activeWorkout.session,
                activeSessionLogs: activeWorkout.logs
            )
        }

        private static func makeActiveWorkout(
            userID: UUID,
            days: [WorkoutDay],
            dayExerciseID: UUID,
            activeDayIndex: Int?,
            completedSetNumbers: [Int]
        ) throws -> (session: WorkoutSession?, logs: [ExerciseLog]) {
            guard let activeDayIndex else { return (nil, []) }

            let session = try WorkoutSession(
                userId: userID,
                workoutDayId: days[activeDayIndex].id
            )
            let logs = try completedSetNumbers.map {
                try ExerciseLog(
                    sessionId: session.id,
                    workoutDayExerciseId: dayExerciseID,
                    weight: 60,
                    reps: 8,
                    setNumber: $0
                )
            }
            return (session, logs)
        }
    }
}
