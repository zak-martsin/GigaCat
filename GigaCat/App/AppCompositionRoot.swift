/// Builds the production dependency graph before SwiftUI creates feature views.
@MainActor
enum AppCompositionRoot {
    /// Creates disk-backed repositories and hydrates their catalog with bundled data.
    static func makeLocalRepositoryFactory() throws -> LocalRepositoryFactory {
        let stack = try SwiftDataStack()
        let catalog = MockSeedData.makeCatalogSeed()

        try SwiftDataBootstrapService(
            context: stack.mainContext,
            catalog: catalog
        ).bootstrapIfNeeded()

        return LocalRepositoryFactory(
            stack: stack,
            currentUserStore: MockSeedData.makeStore()
        )
    }
}
