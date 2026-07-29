import Testing
@testable import GigaCat

@MainActor
struct AppDataChangeCoordinatorTests {

    @Test
    func routesChangesOnlyToAffectedFeatureCaches() async {
        var invalidatedFeatures: Set<String> = []
        let coordinator = AppDataChangeCoordinator(
            invalidateHome: { invalidatedFeatures.insert("home") },
            invalidateLibrary: { invalidatedFeatures.insert("library") },
            invalidateProgress: { invalidatedFeatures.insert("progress") },
            invalidateWorkout: { invalidatedFeatures.insert("workout") }
        )

        await coordinator.handle(.selectedProgram)
        #expect(invalidatedFeatures == ["home", "progress", "workout"])

        invalidatedFeatures = []
        await coordinator.handle(.library)
        #expect(invalidatedFeatures == ["library"])

        invalidatedFeatures = []
        await coordinator.handle(.currentUser)
        #expect(invalidatedFeatures == ["home", "library", "progress", "workout"])
    }
}
