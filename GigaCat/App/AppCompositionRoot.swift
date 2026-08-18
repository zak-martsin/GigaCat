/// Builds the production dependency graph before SwiftUI creates feature views.
@MainActor
enum AppCompositionRoot {
    /// Creates the production local and remote dependencies used by the app root.
    static func makeDependencies() throws -> AppDependencies {
        let currentUserContext = CurrentUserContext()
        let repositoryFactory = try makeLocalRepositoryFactory(
            currentUserIDProvider: currentUserContext
        )
        let configuration = try SupabaseConfiguration.load()
        let supabaseStack = SupabaseStack(configuration: configuration)
        let profileRemoteRepository = SupabaseUserProfileRepository(
            client: supabaseStack.client
        )
        let profileBootstrapService = ProfileBootstrapService(
            remoteRepository: profileRemoteRepository,
            userRepository: repositoryFactory.userRepository,
            outboxRepository: repositoryFactory.syncOutboxRepository
        )
        let syncWorker = SyncWorker(
            outboxRepository: repositoryFactory.syncOutboxRepository,
            remoteExecutor: SupabaseSyncExecutor(
                profileRepository: profileRemoteRepository
            )
        )
        let syncCoordinator = SyncCoordinator(worker: syncWorker)

        return AppDependencies(
            repositoryFactory: repositoryFactory,
            authenticationService: SupabaseAuthenticationService(
                client: supabaseStack.client
            ),
            profileBootstrapService: profileBootstrapService,
            syncCoordinator: syncCoordinator,
            currentUserContext: currentUserContext
        )
    }

    /// Creates disk-backed repositories and hydrates their catalog with bundled data.
    static func makeLocalRepositoryFactory(
        currentUserIDProvider: any CurrentUserIDProviding
    ) throws -> LocalRepositoryFactory {
        let stack = try SwiftDataStack()
        let catalog = MockSeedData.makeCatalogSeed()

        try SwiftDataBootstrapService(
            context: stack.mainContext,
            catalog: catalog
        ).bootstrapIfNeeded()

        return LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: currentUserIDProvider
        )
    }
}

struct AppDependencies {
    let repositoryFactory: LocalRepositoryFactory
    let authenticationService: SupabaseAuthenticationService
    let profileBootstrapService: ProfileBootstrapService
    let syncCoordinator: SyncCoordinator
    let currentUserContext: CurrentUserContext
}
