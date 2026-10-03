#if DEBUG
import Foundation

/// Debug-only composition that keeps UI tests independent from Auth, SwiftData, and the network.
@MainActor
struct UITestAppDependencies {
    static let launchArgument = "--ui-testing"
    static let failedSyncLaunchArgument = "--ui-testing-sync-failed"

    let repositoryFactory: MockRepositoryFactory
    let userID: UUID
    let syncCoordinator: UITestSyncCoordinator
    let systemCatalogSynchronizer: UITestSystemCatalogSynchronizer
    let artworkService: UITestArtworkService
    let profileBootstrapper: UITestProfileBootstrapper
    let profileSyncRecoveryService: UITestProfileSyncRecoveryService

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
            artworkService: UITestArtworkService(),
            profileBootstrapper: UITestProfileBootstrapper(),
            profileSyncRecoveryService: UITestProfileSyncRecoveryService(
                status: ProcessInfo.processInfo.arguments.contains(failedSyncLaunchArgument)
                    ? .failed(message: "Internal database error")
                    : .synchronized
            )
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

struct UITestArtworkService: ArtworkServicing {
    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL {
        throw UITestArtworkError.unavailable
    }
}

private enum UITestArtworkError: Error {
    case unavailable
}

@MainActor
final class UITestProfileBootstrapper: ProfileBootstrapping {
    func bootstrapProfile(for _: UUID) async throws {}

    func refreshProfile(for _: UUID) async throws -> Bool {
        false
    }
}

@MainActor
final class UITestProfileSyncRecoveryService: ProfileSyncRecovering {
    let currentStatus: ProfileSyncStatus

    init(status: ProfileSyncStatus) {
        currentStatus = status
    }

    func status(for _: UUID) throws -> ProfileSyncStatus { currentStatus }
    func retryFailedChange(for _: UUID) async throws {}
    func discardFailedLocalChange(for _: UUID) async throws -> Bool { false }
}
#endif
