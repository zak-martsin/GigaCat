import Foundation

/// Maps domain data changes to cache invalidation without coupling feature ViewModels together.
@MainActor
final class AppDataChangeCoordinator {
    private let invalidateCatalog: @MainActor () -> Void
    private let invalidateProgress: @MainActor () -> Void
    private let invalidateWorkout: @MainActor () -> Void
    private let requestProfileSync: @MainActor () -> Void
    private let refreshWorkoutSessionExpiration: @MainActor () async -> Void

    init(
        invalidateCatalog: @escaping @MainActor () -> Void,
        invalidateProgress: @escaping @MainActor () -> Void,
        invalidateWorkout: @escaping @MainActor () -> Void,
        requestProfileSync: @escaping @MainActor () -> Void = {},
        refreshWorkoutSessionExpiration: @escaping @MainActor () async -> Void = {}
    ) {
        self.invalidateCatalog = invalidateCatalog
        self.invalidateProgress = invalidateProgress
        self.invalidateWorkout = invalidateWorkout
        self.requestProfileSync = requestProfileSync
        self.refreshWorkoutSessionExpiration = refreshWorkoutSessionExpiration
    }

    func handle(_ change: AppDataChange) async {
        switch change {
        case .selectedProgram:
            requestProfileSync()
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
        case .workoutSession:
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
            await refreshWorkoutSessionExpiration()
        case .programCatalog:
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
        }
    }
}
