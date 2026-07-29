import Foundation

/// Owns the application-scoped feature graph and keeps dependency construction out of SwiftUI views.
@MainActor
final class AppContainer {
    let homeViewModel: HomeViewModel
    let libraryViewModel: LibraryViewModel
    let progressViewModel: ProgressViewModel
    let workoutViewModel: WorkoutViewModel
    private let dataChangeCoordinator: AppDataChangeCoordinator
    private let dataChangeDispatcher: AppDataChangeDispatcher

    init(repositoryFactory: MockRepositoryFactory) {
        let dataChangeDispatcher = AppDataChangeDispatcher()
        let programDetailService = ProgramDetailService(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let homeViewModel = HomeViewModel(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository,
            programDetailService: programDetailService
        )
        let progressHistoryService = ProgressHistoryService(
            userRepository: repositoryFactory.userRepository,
            workoutRepository: repositoryFactory.workoutRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository
        )
        let progressViewModel = ProgressViewModel(
            historyService: progressHistoryService
        )
        let workoutContextService = WorkoutContextService(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let libraryViewModel = LibraryViewModel(
            userRepository: repositoryFactory.userRepository,
            libraryRepository: repositoryFactory.workoutProgramLibraryRepository,
            programDetailService: programDetailService,
            onDataChanged: dataChangeDispatcher.send
        )
        let workoutViewModel = WorkoutViewModel(
            contextService: workoutContextService,
            workoutRepository: repositoryFactory.workoutRepository,
            onDataChanged: dataChangeDispatcher.send
        )
        let dataChangeCoordinator = AppDataChangeCoordinator(
            invalidateHome: { [weak homeViewModel] in
                homeViewModel?.invalidate()
            },
            invalidateLibrary: { [weak libraryViewModel] in
                libraryViewModel?.invalidate()
            },
            invalidateProgress: { [weak progressViewModel] in
                progressViewModel?.invalidate()
            },
            invalidateWorkout: { [weak workoutViewModel] in
                workoutViewModel?.invalidate()
            }
        )

        self.homeViewModel = homeViewModel
        self.progressViewModel = progressViewModel
        self.libraryViewModel = libraryViewModel
        self.workoutViewModel = workoutViewModel
        self.dataChangeCoordinator = dataChangeCoordinator
        self.dataChangeDispatcher = dataChangeDispatcher

        dataChangeDispatcher.install(handler: dataChangeCoordinator.handle)
    }
}
