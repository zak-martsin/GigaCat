import Testing
@testable import GigaCat

@MainActor
struct AppDataChangeCoordinatorTests {

    @Test
    func routesChangesOnlyToAffectedFeatureCaches() async {
        var invalidatedFeatures: Set<String> = []
        var profileSyncRequestCount = 0
        var expirationRefreshCount = 0
        let coordinator = AppDataChangeCoordinator(
            invalidateCatalog: { invalidatedFeatures.insert("catalog") },
            invalidateProgress: { invalidatedFeatures.insert("progress") },
            invalidateWorkout: { invalidatedFeatures.insert("workout") },
            requestProfileSync: { profileSyncRequestCount += 1 },
            refreshWorkoutSessionExpiration: { expirationRefreshCount += 1 }
        )

        await coordinator.handle(.selectedProgram)
        #expect(invalidatedFeatures == ["catalog", "progress", "workout"])
        #expect(profileSyncRequestCount == 1)
        #expect(expirationRefreshCount == 0)

        invalidatedFeatures = []
        await coordinator.handle(.workoutSession)
        #expect(invalidatedFeatures == ["catalog", "progress", "workout"])
        #expect(profileSyncRequestCount == 1)
        #expect(expirationRefreshCount == 1)

    }
}
