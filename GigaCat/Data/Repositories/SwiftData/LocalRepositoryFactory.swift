//
//  LocalRepositoryFactory.swift
//  GigaCat
//
//  Created by OpenAI on 14/08/2026.
//

/// Creates local repositories that share one SwiftData container and main context.
@MainActor
struct LocalRepositoryFactory: RepositoryFactory {
    let programCatalogRepository: ProgramCatalogRepository
    let userRepository: UserRepository
    let workoutProgramRepository: WorkoutProgramRepository
    let workoutProgramLibraryRepository: WorkoutProgramLibraryRepository
    let workoutRepository: WorkoutRepository

    private let stack: SwiftDataStack

    /// Uses a mock store only until authenticated-user lookup has a dedicated provider.
    init(stack: SwiftDataStack, currentUserStore: MockDataStore) {
        self.stack = stack

        let context = stack.mainContext
        programCatalogRepository = LocalProgramCatalogRepository(context: context)
        userRepository = LocalUserRepository(
            context: context,
            store: currentUserStore
        )
        workoutProgramRepository = LocalWorkoutProgramRepository(context: context)
        workoutProgramLibraryRepository = LocalWorkoutProgramLibraryRepository(context: context)
        workoutRepository = LocalWorkoutRepository(context: context)
    }
}
