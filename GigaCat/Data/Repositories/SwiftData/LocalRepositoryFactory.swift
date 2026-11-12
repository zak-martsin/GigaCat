//
//  LocalRepositoryFactory.swift
//  GigaCat
//
//  Created by OpenAI on 14/08/2026.
//

/// Creates local repositories that share one SwiftData container and main context.
@MainActor
struct LocalRepositoryFactory: RepositoryFactory {
    let profileChanges: ProfileChangeSource
    let defaultProgramCatalogRepository: DefaultProgramCatalogRepository
    let userRepository: UserRepository
    let workoutProgramRepository: WorkoutProgramRepository
    let workoutRepository: WorkoutRepository
    let syncOutboxRepository: LocalSyncOutboxRepository
    let systemCatalogStore: LocalSystemCatalogStore

    private let stack: SwiftDataStack

    init(
        stack: SwiftDataStack,
        currentUserIDProvider: any CurrentUserIDProviding
    ) {
        self.stack = stack

        let context = stack.mainContext
        let profileChanges = ProfileChangeSource()
        self.profileChanges = profileChanges
        defaultProgramCatalogRepository = LocalDefaultProgramCatalogRepository(context: context)
        userRepository = LocalUserRepository(
            context: context,
            currentUserIDProvider: currentUserIDProvider,
            profileChanges: profileChanges
        )
        workoutProgramRepository = LocalWorkoutProgramRepository(context: context)
        workoutRepository = LocalWorkoutRepository(context: context)
        syncOutboxRepository = LocalSyncOutboxRepository(context: context, profileChanges: profileChanges)
        systemCatalogStore = LocalSystemCatalogStore(context: context)
    }
}
