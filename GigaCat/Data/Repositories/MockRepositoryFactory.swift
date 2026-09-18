import Foundation

/// Creates a coherent set of mock repositories backed by shared in-memory data.
struct MockRepositoryFactory: RepositoryFactory {
    let defaultProgramCatalogRepository: DefaultProgramCatalogRepository
    let userRepository: UserRepository
    let workoutProgramRepository: WorkoutProgramRepository
    let workoutRepository: WorkoutRepository

    init(store: MockDataStore) {
        defaultProgramCatalogRepository = MockDefaultProgramCatalogRepository(store: store)
        userRepository = MockUserRepository(store: store)
        workoutProgramRepository = MockWorkoutProgramRepository(store: store)
        workoutRepository = MockWorkoutRepository(store: store)
    }

    init() throws {
        self.init(store: try MockSeedData.makeStore())
    }
}
