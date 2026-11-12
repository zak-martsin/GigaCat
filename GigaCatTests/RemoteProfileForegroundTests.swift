import Foundation
import Testing
@testable import GigaCat

@MainActor
struct RemoteProfileForegroundTests {
    @Test
    func goalOnlyRemoteChangeInvalidatesWorkoutWithoutProgramSelectionChange() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.factory.workoutRepository.startSession(
            userId: fixture.user.id, workoutDayId: fixture.day.id, startedAt: Date()
        )
        let remote = fixture.user.updatingTraining(goal: .maintain, level: .advanced)
        let container = AppContainer(
            repositoryFactory: fixture.factory, syncCoordinator: RemoteTrainingSyncStub(),
            systemCatalogSynchronizer: RemoteProfileCatalogStub(), artworkService: RemoteProfileArtworkStub(),
            profileBootstrapper: ProfileBootstrapService(
                remoteRepository: RemoteTrainingProfileStub(profileValue: remote),
                userRepository: fixture.factory.userRepository, outboxRepository: fixture.factory.syncOutboxRepository
            )
        )
        defer { container.pauseSessionExpirationMonitoring() }
        await container.workoutViewModel.load()
        #expect(container.workoutViewModel.context?.activeSession?.exerciseTargets?.map(\.targetSets) == [4, 5, 4])
        let result = await container.refreshAfterBecomingActive(for: fixture.user.id)
        #expect(result.didChange)
        await container.workoutViewModel.loadIfNeeded()
        #expect(container.workoutViewModel.context?.activeSession?.exerciseTargets?.map(\.targetSets) == [3, 5, 3])
        #expect(try await fixture.factory.userRepository.currentUser()?.selectedProgramId == nil)
        #expect(await container.refreshAfterBecomingActive(for: fixture.user.id).didChange == false)
    }
}

@MainActor
private final class RemoteProfileCatalogStub: SystemCatalogSyncing {
    func refreshSystemCatalog() async throws -> Bool { false }
}

private struct RemoteProfileArtworkStub: ArtworkServicing {
    func fileURL(for _: ArtworkOwner, artwork _: ArtworkReference) async throws -> URL {
        throw CocoaError(.fileNoSuchFile)
    }
}
