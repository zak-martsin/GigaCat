import Foundation

/// Owns the application-scoped feature graph and keeps dependency construction out of SwiftUI views.
@MainActor
final class AppContainer {
    let homeViewModel: HomeViewModel
    let libraryViewModel: LibraryViewModel
    let progressViewModel: ProgressViewModel
    let workoutViewModel: WorkoutViewModel

    init(repositoryFactory: MockRepositoryFactory) {
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

        self.homeViewModel = homeViewModel
        self.progressViewModel = progressViewModel
        libraryViewModel = LibraryViewModel(
            userRepository: repositoryFactory.userRepository,
            libraryRepository: repositoryFactory.workoutProgramLibraryRepository,
            programDetailService: programDetailService,
            onProgramDataChanged: {
                homeViewModel.invalidate()
                progressViewModel.invalidate()
            }
        )
        workoutViewModel = WorkoutViewModel(
            contextService: workoutContextService,
            workoutRepository: repositoryFactory.workoutRepository,
            onWorkoutDataChanged: {
                homeViewModel.invalidate()
                progressViewModel.invalidate()
            }
        )
    }
}
