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
    let syncOutboxRepository: LocalSyncOutboxRepository

    private let stack: SwiftDataStack

    init(
        stack: SwiftDataStack,
        currentUserIDProvider: any CurrentUserIDProviding
    ) {
        self.stack = stack

        let context = stack.mainContext
        programCatalogRepository = LocalProgramCatalogRepository(context: context)
        userRepository = LocalUserRepository(
            context: context,
            currentUserIDProvider: currentUserIDProvider
        )
        workoutProgramRepository = LocalWorkoutProgramRepository(context: context)
        workoutProgramLibraryRepository = LocalWorkoutProgramLibraryRepository(context: context)
        workoutRepository = LocalWorkoutRepository(context: context)
        syncOutboxRepository = LocalSyncOutboxRepository(context: context)
    }
}
