import Foundation

/// Maps domain data changes to cache invalidation without coupling feature ViewModels together.
@MainActor
final class AppDataChangeCoordinator {
    private let invalidateHome: @MainActor () -> Void
    private let invalidateLibrary: @MainActor () -> Void
    private let invalidateProgress: @MainActor () -> Void

    init(
        invalidateHome: @escaping @MainActor () -> Void,
        invalidateLibrary: @escaping @MainActor () -> Void,
        invalidateProgress: @escaping @MainActor () -> Void
    ) {
        self.invalidateHome = invalidateHome
        self.invalidateLibrary = invalidateLibrary
        self.invalidateProgress = invalidateProgress
    }

    func handle(_ change: AppDataChange) async {
        switch change {
        case .selectedProgram:
            invalidateHome()
            invalidateProgress()
        case .workoutSession:
            invalidateHome()
            invalidateProgress()
        case .library:
            invalidateLibrary()
        case .programCatalog:
            invalidateHome()
            invalidateLibrary()
            invalidateProgress()
        case .currentUser:
            invalidateHome()
            invalidateLibrary()
            invalidateProgress()
        }
    }
}
