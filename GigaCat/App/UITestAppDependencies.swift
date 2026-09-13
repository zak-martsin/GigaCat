#if DEBUG
import Foundation

/// Debug-only composition that keeps UI tests independent from Auth, SwiftData, and the network.
@MainActor
struct UITestAppDependencies {
    static let launchArgument = "--ui-testing"

    let repositoryFactory: MockRepositoryFactory
    let userID: UUID
    let syncCoordinator: UITestSyncCoordinator
    let systemCatalogSynchronizer: UITestSystemCatalogSynchronizer
    let profileBootstrapper: UITestProfileBootstrapper

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func make(now: Date = Date()) throws -> UITestAppDependencies {
        let store = try MockSeedData.makeStore(now: now)
        return UITestAppDependencies(
            repositoryFactory: MockRepositoryFactory(store: store),
            userID: MockSeedData.uuid("11111111-1111-1111-1111-111111111111"),
            syncCoordinator: UITestSyncCoordinator(),
            systemCatalogSynchronizer: UITestSystemCatalogSynchronizer(),
            profileBootstrapper: UITestProfileBootstrapper()
        )
    }
}

@MainActor
final class UITestSyncCoordinator: SyncCoordinating {
    func activate(for userID: UUID) async {}
    func deactivate() async {}
    func requestSync() async {}
}

@MainActor
final class UITestSystemCatalogSynchronizer: SystemCatalogSyncing {
    func refreshSystemCatalog() async throws -> Bool {
        false
    }
}

@MainActor
final class UITestProfileBootstrapper: ProfileBootstrapping {
    func bootstrapProfile(for _: UUID) async throws {}

    func refreshProfile(for _: UUID) async throws -> Bool {
        false
    }
}
#endif
