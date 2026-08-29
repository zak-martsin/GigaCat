import Testing
@testable import GigaCat

@MainActor
struct AppDataChangeCoordinatorTests {

    @Test
    func routesChangesOnlyToAffectedFeatureCaches() async {
        var invalidatedFeatures: Set<String> = []
        var miniPlayerReloadCount = 0
        var profileSyncRequestCount = 0
        let coordinator = AppDataChangeCoordinator(
            invalidateCatalog: { invalidatedFeatures.insert("catalog") },
            invalidateProgress: { invalidatedFeatures.insert("progress") },
            invalidateWorkout: { invalidatedFeatures.insert("workout") },
            reloadMiniPlayer: { miniPlayerReloadCount += 1 },
            requestProfileSync: { profileSyncRequestCount += 1 }
        )

        await coordinator.handle(.selectedProgram)
        #expect(invalidatedFeatures == ["catalog", "progress", "workout"])
        #expect(miniPlayerReloadCount == 1)
        #expect(profileSyncRequestCount == 1)

        invalidatedFeatures = []
        await coordinator.handle(.workoutSession)
        #expect(invalidatedFeatures == ["catalog", "progress", "workout"])
        #expect(miniPlayerReloadCount == 2)
        #expect(profileSyncRequestCount == 1)

    }
}
