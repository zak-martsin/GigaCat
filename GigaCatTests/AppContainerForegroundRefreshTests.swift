import Foundation
import Testing
@testable import GigaCat

@MainActor
struct AppContainerForegroundRefreshTests {

    @Test
    func foregroundRefreshRunsCatalogPushAndProfilePullInOrder() async throws {
        let recorder = ForegroundRefreshRecorder()
        let factory = try MockRepositoryFactory()
        let userID = try #require(await factory.userRepository.currentUser()?.id)
        let container = AppContainer(
            repositoryFactory: factory,
            syncCoordinator: ForegroundSyncCoordinatorSpy(recorder: recorder),
            systemCatalogSynchronizer: ForegroundCatalogSynchronizerSpy(
                recorder: recorder
            ),
            profileBootstrapper: ForegroundProfileBootstrapperSpy(
                recorder: recorder
            )
        )

        let didChange = await container.refreshAfterBecomingActive(for: userID)

        #expect(!didChange)
        #expect(recorder.events == ["catalog", "push", "profile"])
    }

    @Test
    func foregroundRefreshClearsInactiveSelectedProgram() async throws {
        let userID = UUID()
        let inactiveProgram = try WorkoutProgram(
            isActive: false,
            title: "Inactive",
            description: "Inactive"
        )
        let store = MockDataStore(
            users: [User(id: userID, selectedProgramId: inactiveProgram.id)],
            programs: [inactiveProgram],
            currentUserID: userID
        )
        let factory = MockRepositoryFactory(store: store)
        let container = AppContainer(
            repositoryFactory: factory,
            syncCoordinator: ForegroundSyncCoordinatorSpy(),
            systemCatalogSynchronizer: ForegroundCatalogSynchronizerSpy(),
            profileBootstrapper: ForegroundProfileBootstrapperSpy()
        )

        let didChange = await container.refreshAfterBecomingActive(for: userID)

        let updatedUser = try #require(
            try await factory.userRepository.user(id: userID)
        )
        #expect(didChange)
        #expect(updatedUser.selectedProgramId == nil)
    }

    @Test
    func foregroundRefreshClearsMissingSelectedProgram() async throws {
        let userID = UUID()
        let missingProgramID = UUID()
        let store = MockDataStore(
            users: [User(id: userID, selectedProgramId: missingProgramID)],
            currentUserID: userID
        )
        let factory = MockRepositoryFactory(store: store)
        let container = AppContainer(
            repositoryFactory: factory,
            syncCoordinator: ForegroundSyncCoordinatorSpy(),
            systemCatalogSynchronizer: ForegroundCatalogSynchronizerSpy(),
            profileBootstrapper: ForegroundProfileBootstrapperSpy()
        )

        let didChange = await container.refreshAfterBecomingActive(for: userID)

        let updatedUser = try #require(
            try await factory.userRepository.user(id: userID)
        )
        #expect(didChange)
        #expect(updatedUser.selectedProgramId == nil)
    }
}

@MainActor
private final class ForegroundRefreshRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

@MainActor
private final class ForegroundSyncCoordinatorSpy: SyncCoordinating {
    private let recorder: ForegroundRefreshRecorder?

    init(recorder: ForegroundRefreshRecorder? = nil) {
        self.recorder = recorder
    }

    func activate(for _: UUID) async {}

    func deactivate() async {}

    func requestSync() async {
        recorder?.record("push")
    }
}

@MainActor
private final class ForegroundCatalogSynchronizerSpy: SystemCatalogSyncing {
    private let recorder: ForegroundRefreshRecorder?

    init(recorder: ForegroundRefreshRecorder? = nil) {
        self.recorder = recorder
    }

    func refreshSystemCatalog() async throws -> Bool {
        recorder?.record("catalog")
        return false
    }
}

@MainActor
private final class ForegroundProfileBootstrapperSpy: ProfileBootstrapping {
    private let recorder: ForegroundRefreshRecorder?

    init(recorder: ForegroundRefreshRecorder? = nil) {
        self.recorder = recorder
    }

    func bootstrapProfile(for _: UUID) async throws {}

    func refreshProfile(for _: UUID) async throws -> Bool {
        recorder?.record("profile")
        return false
    }
}
