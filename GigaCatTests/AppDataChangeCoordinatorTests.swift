import Testing
@testable import GigaCat

@MainActor
struct AppDataChangeCoordinatorTests {

    @Test
    func routesChangesOnlyToAffectedFeatureCaches() async {
        var invalidatedFeatures: Set<String> = []
        var miniPlayerReloadCount = 0
        let coordinator = AppDataChangeCoordinator(
            invalidateHome: { invalidatedFeatures.insert("home") },
            invalidateLibrary: { invalidatedFeatures.insert("library") },
            invalidateProgress: { invalidatedFeatures.insert("progress") },
            invalidateWorkout: { invalidatedFeatures.insert("workout") },
            reloadMiniPlayer: { miniPlayerReloadCount += 1 }
        )

        await coordinator.handle(.selectedProgram)
        #expect(invalidatedFeatures == ["home", "progress", "workout"])
        #expect(miniPlayerReloadCount == 1)

        invalidatedFeatures = []
        await coordinator.handle(.library)
        #expect(invalidatedFeatures == ["library"])
        #expect(miniPlayerReloadCount == 1)

        invalidatedFeatures = []
        await coordinator.handle(.currentUser)
        #expect(invalidatedFeatures == ["home", "library", "progress", "workout"])
        #expect(miniPlayerReloadCount == 2)
    }
}
