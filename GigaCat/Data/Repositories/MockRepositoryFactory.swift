import Foundation

/// Creates a coherent set of mock repositories backed by shared in-memory data.
struct MockRepositoryFactory {
    let userRepository: UserRepository
    let workoutProgramRepository: WorkoutProgramRepository
    let workoutRepository: WorkoutRepository

    init(store: MockDataStore = MockSeedData.makeStore()) {
        userRepository = MockUserRepository(store: store)
        workoutProgramRepository = MockWorkoutProgramRepository(store: store)
        workoutRepository = MockWorkoutRepository(store: store)
    }
}
