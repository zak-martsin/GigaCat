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

        return AppDependencies(
            repositoryFactory: repositoryFactory,
            authenticationService: SupabaseAuthenticationService(
                client: supabaseStack.client
            ),
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
    let currentUserContext: CurrentUserContext
}
