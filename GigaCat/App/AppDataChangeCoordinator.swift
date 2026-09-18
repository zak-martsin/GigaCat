import Foundation

/// Maps domain data changes to cache invalidation without coupling feature ViewModels together.
@MainActor
final class AppDataChangeCoordinator {
    private let invalidateCatalog: @MainActor () -> Void
    private let invalidateProgress: @MainActor () -> Void
    private let invalidateWorkout: @MainActor () -> Void
    private let reloadMiniPlayer: @MainActor () async -> Void
    private let requestProfileSync: @MainActor () -> Void

    init(
        invalidateCatalog: @escaping @MainActor () -> Void,
        invalidateProgress: @escaping @MainActor () -> Void,
        invalidateWorkout: @escaping @MainActor () -> Void,
        reloadMiniPlayer: @escaping @MainActor () async -> Void,
        requestProfileSync: @escaping @MainActor () -> Void = {}
    ) {
        self.invalidateCatalog = invalidateCatalog
        self.invalidateProgress = invalidateProgress
        self.invalidateWorkout = invalidateWorkout
        self.reloadMiniPlayer = reloadMiniPlayer
        self.requestProfileSync = requestProfileSync
    }

    func handle(_ change: AppDataChange) async {
        switch change {
        case .selectedProgram:
            requestProfileSync()
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        case .workoutSession:
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        case .programCatalog:
            invalidateCatalog()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        }
    }
}
