import Foundation

/// Owns the application-scoped feature graph and keeps dependency construction out of SwiftUI views.
@MainActor
final class AppContainer {
    let homeViewModel: HomeViewModel
    let libraryViewModel: LibraryViewModel
    let progressViewModel: ProgressViewModel
    let workoutViewModel: WorkoutViewModel
    let miniPlayerViewModel: MiniPlayerViewModel
    let programDetailViewModel: ProgramDetailViewModel
    private let dataChangeCoordinator: AppDataChangeCoordinator
    private let dataChangeDispatcher: AppDataChangeDispatcher

    // The composition root keeps the complete dependency graph visible in one place.
    // swiftlint:disable:next function_body_length
    init(repositoryFactory: MockRepositoryFactory) {
        let dataChangeDispatcher = AppDataChangeDispatcher()
        let programDetailService = ProgramDetailService(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            libraryRepository: repositoryFactory.workoutProgramLibraryRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let miniPlayerService = MiniPlayerService(
            userRepository: repositoryFactory.userRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let miniPlayerViewModel = MiniPlayerViewModel(
            service: miniPlayerService,
            workoutRepository: repositoryFactory.workoutRepository,
            onDataChanged: dataChangeDispatcher.send
        )
        let programDetailViewModel = ProgramDetailViewModel(
            userRepository: repositoryFactory.userRepository,
            libraryRepository: repositoryFactory.workoutProgramLibraryRepository,
            service: programDetailService,
            onDataChanged: dataChangeDispatcher.send
        )
        let homeViewModel = HomeViewModel(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            libraryRepository: repositoryFactory.workoutProgramLibraryRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository,
            programDetailService: programDetailService,
            onDataChanged: dataChangeDispatcher.send
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
            },
            reloadMiniPlayer: { [weak miniPlayerViewModel] in
                await miniPlayerViewModel?.reload()
            }
        )

        self.homeViewModel = homeViewModel
        self.progressViewModel = progressViewModel
        self.libraryViewModel = libraryViewModel
        self.workoutViewModel = workoutViewModel
        self.miniPlayerViewModel = miniPlayerViewModel
        self.programDetailViewModel = programDetailViewModel
        self.dataChangeCoordinator = dataChangeCoordinator
        self.dataChangeDispatcher = dataChangeDispatcher

        dataChangeDispatcher.install(handler: dataChangeCoordinator.handle)
    }
}
