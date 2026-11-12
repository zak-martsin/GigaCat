/// Provides the repository set required to construct the application feature graph.
protocol RepositoryFactory {
    var profileChanges: ProfileChangeSource { get }
    var defaultProgramCatalogRepository: DefaultProgramCatalogRepository { get }
    var userRepository: UserRepository { get }
    var workoutProgramRepository: WorkoutProgramRepository { get }
    var workoutRepository: WorkoutRepository { get }
}
