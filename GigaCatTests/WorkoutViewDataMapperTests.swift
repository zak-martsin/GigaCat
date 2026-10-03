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
                    exerciseID: fixture.exercise.id,
                    name: fixture.exercise.name,
                    targetSets: 4,
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
}

private extension WorkoutViewDataMapperTests {
    struct Fixture {
        let firstDay: WorkoutDay
        let secondDay: WorkoutDay
        let exercise: Exercise
        let dayExercise: WorkoutDayExercise
        let context: WorkoutContext

        init(hasArtwork: Bool = false) throws {
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
