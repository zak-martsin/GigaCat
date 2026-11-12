import Foundation

/// Creates a coherent set of mock repositories backed by shared in-memory data.
struct MockRepositoryFactory: RepositoryFactory {
    let profileChanges: ProfileChangeSource
    let defaultProgramCatalogRepository: DefaultProgramCatalogRepository
    let userRepository: UserRepository
    let workoutProgramRepository: WorkoutProgramRepository
    let workoutRepository: WorkoutRepository

    init(store: MockDataStore) {
        let profileChanges = ProfileChangeSource()
        self.profileChanges = profileChanges
        defaultProgramCatalogRepository = MockDefaultProgramCatalogRepository(store: store)
        userRepository = MockUserRepository(store: store, profileChanges: profileChanges)
        workoutProgramRepository = MockWorkoutProgramRepository(store: store)
        workoutRepository = MockWorkoutRepository(store: store)
    }

    init() throws {
        self.init(store: try MockSeedData.makeStore())
    }
}
