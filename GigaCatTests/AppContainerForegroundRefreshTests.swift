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

        let result = await container.refreshAfterBecomingActive(for: userID)

        #expect(!result.didChange)
        #expect(!result.selectedProgramBecameUnavailable)
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

        let result = await container.refreshAfterBecomingActive(for: userID)
        let repeatedResult = await container.refreshAfterBecomingActive(for: userID)

        let updatedUser = try #require(
            try await factory.userRepository.user(id: userID)
        )
        #expect(result.didChange)
        #expect(result.selectedProgramBecameUnavailable)
        #expect(!repeatedResult.selectedProgramBecameUnavailable)
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

        let result = await container.refreshAfterBecomingActive(for: userID)

        let updatedUser = try #require(
            try await factory.userRepository.user(id: userID)
        )
        #expect(result.didChange)
        #expect(result.selectedProgramBecameUnavailable)
        #expect(updatedUser.selectedProgramId == nil)
    }

    @Test
    func failedCatalogRefreshDoesNotClearSelection() async throws {
        let userID = UUID()
        let selectedProgramID = UUID()
        let recorder = ForegroundRefreshRecorder()
        let factory = MockRepositoryFactory(
            store: MockDataStore(
                users: [User(id: userID, selectedProgramId: selectedProgramID)],
                currentUserID: userID
            )
        )
        let container = AppContainer(
            repositoryFactory: factory,
            syncCoordinator: ForegroundSyncCoordinatorSpy(recorder: recorder),
            systemCatalogSynchronizer: ForegroundCatalogSynchronizerSpy(
                recorder: recorder,
                shouldFail: true
            ),
            profileBootstrapper: ForegroundProfileBootstrapperSpy(recorder: recorder)
        )

        let result = await container.refreshAfterBecomingActive(for: userID)

        #expect(!result.didChange)
        #expect(!result.selectedProgramBecameUnavailable)
        #expect(try await factory.userRepository.user(id: userID)?.selectedProgramId == selectedProgramID)
        #expect(recorder.events == ["catalog", "push", "profile"])
    }

    @Test
    func overlappingForegroundRequestsShareOnePass() async throws {
        let recorder = ForegroundRefreshRecorder()
        let factory = try MockRepositoryFactory()
        let userID = try #require(await factory.userRepository.currentUser()?.id)
        let catalog = ForegroundCatalogSynchronizerSpy(recorder: recorder, shouldSuspend: true)
        let container = AppContainer(
            repositoryFactory: factory,
            syncCoordinator: ForegroundSyncCoordinatorSpy(recorder: recorder),
            systemCatalogSynchronizer: catalog,
            profileBootstrapper: ForegroundProfileBootstrapperSpy(recorder: recorder)
        )

        let first = Task { await container.refreshAfterBecomingActive(for: userID) }
        while catalog.refreshCount == 0 {
            await Task.yield()
        }
        let second = Task { await container.refreshAfterBecomingActive(for: userID) }
        await Task.yield()
        catalog.resume()

        let firstResult = await first.value
        let secondResult = await second.value
        #expect(firstResult == secondResult)
        #expect(catalog.refreshCount == 1)
        #expect(recorder.events == ["catalog", "push", "profile"])
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
    private let shouldFail: Bool
    private let shouldSuspend: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var refreshCount = 0

    init(
        recorder: ForegroundRefreshRecorder? = nil,
        shouldFail: Bool = false,
        shouldSuspend: Bool = false
    ) {
        self.recorder = recorder
        self.shouldFail = shouldFail
        self.shouldSuspend = shouldSuspend
    }

    func refreshSystemCatalog() async throws -> Bool {
        refreshCount += 1
        recorder?.record("catalog")
        if shouldSuspend {
            await withCheckedContinuation { continuation = $0 }
        }
        if shouldFail {
            throw ForegroundCatalogError.unavailable
        }
        return false
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private enum ForegroundCatalogError: Error {
    case unavailable
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
