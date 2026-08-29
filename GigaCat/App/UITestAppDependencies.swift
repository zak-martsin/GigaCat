#if DEBUG
import Foundation

/// Debug-only composition that keeps UI tests independent from Auth, SwiftData, and the network.
@MainActor
struct UITestAppDependencies {
    static let launchArgument = "--ui-testing"

    let repositoryFactory: MockRepositoryFactory
    let syncCoordinator: UITestSyncCoordinator
    let systemCatalogSynchronizer: UITestSystemCatalogSynchronizer

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func make(now: Date = Date()) throws -> UITestAppDependencies {
        let store = try MockSeedData.makeStore(now: now)
        return UITestAppDependencies(
            repositoryFactory: MockRepositoryFactory(store: store),
            syncCoordinator: UITestSyncCoordinator(),
            systemCatalogSynchronizer: UITestSystemCatalogSynchronizer()
        )
    }
}

@MainActor
final class UITestSyncCoordinator: SyncCoordinating {
    func activate(for userID: UUID) {}
    func deactivate() {}
    func requestSync() {}
}

@MainActor
final class UITestSystemCatalogSynchronizer: SystemCatalogSyncing {
    func refreshSystemCatalog() async throws -> Bool {
        false
    }
}
#endif
