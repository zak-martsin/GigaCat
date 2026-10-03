import Foundation
import Testing
@testable import GigaCat

@MainActor
struct WorkoutExerciseArtworkViewModelTests {
    @Test
    func loadsArtworkOnlyForSelectedExercise() async throws {
        let fixture = try Fixture()
        let service = ArtworkServiceTestDouble(
            fileURL: URL(filePath: "/tmp/selected-exercise.png")
        )
        let viewModel = fixture.makeViewModel(artworkService: service)

        #expect(await service.requests.isEmpty)
        await viewModel.loadSelectedArtwork()

        #expect(viewModel.artworkFileURL?.lastPathComponent == "selected-exercise.png")
        #expect(
            await service.requests == [
                .init(
                    owner: .exercise(fixture.first.exercise.id),
                    artwork: fixture.artwork
                )
            ]
        )

        viewModel.selectNextExercise()
        #expect(viewModel.artworkFileURL == nil)
        #expect(await service.requests.count == 1)
    }

    @Test
    func selectedArtworkFailureKeepsPlaceholderState() async throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel(
            artworkService: ArtworkServiceTestDouble(error: .unavailable)
        )

        await viewModel.loadSelectedArtwork()

        #expect(viewModel.artworkFileURL == nil)
    }
}

private extension WorkoutExerciseArtworkViewModelTests {
    struct Fixture {
        let user = User()
        let artwork: ArtworkReference
        let first: WorkoutExerciseContent
        let dayContent: WorkoutDayContent
        let repository: MockWorkoutRepository

        init() throws {
            artwork = try ArtworkReference(path: "exercise/main.png", revision: 1)
            let day = try WorkoutDay(
                programId: UUID(),
                title: "Strength Day",
                orderIndex: 0
            )
            first = try Self.makeContent(
                name: "Bench Press",
                dayID: day.id,
                orderIndex: 0,
                artwork: artwork
            )
            let second = try Self.makeContent(
                name: "Incline Press",
                dayID: day.id,
                orderIndex: 1,
                artwork: artwork
            )
            dayContent = WorkoutDayContent(day: day, exercises: [first, second])
            repository = MockWorkoutRepository(store: MockDataStore())
        }

        @MainActor
        func makeViewModel(
            artworkService: any ArtworkServicing
        ) -> WorkoutExerciseViewModel {
            WorkoutExerciseViewModel(
                userID: user.id,
                activeSession: nil,
                dayContent: dayContent,
                initialDayExerciseID: first.dayExercise.id,
                workoutRepository: repository,
                artworkService: artworkService
            )
        }

        private static func makeContent(
            name: String,
            dayID: UUID,
            orderIndex: Int,
            artwork: ArtworkReference
        ) throws -> WorkoutExerciseContent {
            let exercise = try Exercise(
                name: name,
                muscleGroup: .chest,
                artwork: artwork
            )
            let dayExercise = try WorkoutDayExercise(
                workoutDayId: dayID,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: orderIndex
            )
            return WorkoutExerciseContent(
                dayExercise: dayExercise,
                exercise: exercise
            )
        }
    }
}
