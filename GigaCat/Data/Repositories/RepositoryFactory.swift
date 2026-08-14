/// Provides the repository set required to construct the application feature graph.
protocol RepositoryFactory {
    var programCatalogRepository: ProgramCatalogRepository { get }
    var userRepository: UserRepository { get }
    var workoutProgramRepository: WorkoutProgramRepository { get }
    var workoutProgramLibraryRepository: WorkoutProgramLibraryRepository { get }
    var workoutRepository: WorkoutRepository { get }
}
