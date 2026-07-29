import Foundation

/// Maps domain data changes to cache invalidation without coupling feature ViewModels together.
@MainActor
final class AppDataChangeCoordinator {
    private let invalidateHome: @MainActor () -> Void
    private let invalidateLibrary: @MainActor () -> Void
    private let invalidateProgress: @MainActor () -> Void
    private let invalidateWorkout: @MainActor () -> Void
    private let reloadMiniPlayer: @MainActor () async -> Void

    init(
        invalidateHome: @escaping @MainActor () -> Void,
        invalidateLibrary: @escaping @MainActor () -> Void,
        invalidateProgress: @escaping @MainActor () -> Void,
        invalidateWorkout: @escaping @MainActor () -> Void,
        reloadMiniPlayer: @escaping @MainActor () async -> Void
    ) {
        self.invalidateHome = invalidateHome
        self.invalidateLibrary = invalidateLibrary
        self.invalidateProgress = invalidateProgress
        self.invalidateWorkout = invalidateWorkout
        self.reloadMiniPlayer = reloadMiniPlayer
    }

    func handle(_ change: AppDataChange) async {
        switch change {
        case .selectedProgram:
            invalidateHome()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        case .workoutSession:
            invalidateHome()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        case .library:
            invalidateLibrary()
        case .programCatalog:
            invalidateHome()
            invalidateLibrary()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        case .currentUser:
            invalidateHome()
            invalidateLibrary()
            invalidateProgress()
            invalidateWorkout()
            await reloadMiniPlayer()
        }
    }
}
