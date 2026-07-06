import Foundation

/// In-memory source for predefined programs and exercise metadata.
struct MockWorkoutProgramRepository: WorkoutProgramRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func fetchPrograms() async throws -> [WorkoutProgram] {
        await store.programs()
    }

    func fetchProgram(id: UUID) async throws -> WorkoutProgram? {
        await store.program(id: id)
    }

    func fetchWorkoutDays(programId: UUID) async throws -> [WorkoutDay] {
        await store.workoutDays(programId: programId)
    }

    func fetchWorkoutDay(id: UUID) async throws -> WorkoutDay? {
        await store.workoutDay(id: id)
    }

    func fetchWorkoutDayExercises(workoutDayId: UUID) async throws -> [WorkoutDayExercise] {
        await store.workoutDayExercises(workoutDayId: workoutDayId)
    }

    func fetchExercise(id: UUID) async throws -> Exercise? {
        await store.exercise(id: id)
    }
}
