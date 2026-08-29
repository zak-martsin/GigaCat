import Foundation

/// Catalog entry for one server-owned default workout program.
struct ProgramCatalogEntry: Identifiable, Equatable, Sendable {
    let program: WorkoutProgram

    var id: UUID {
        program.id
    }
}

/// Read-only access to the shared catalog of server-owned default programs.
protocol DefaultProgramCatalogRepository {
    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry]
}

/// Complete server-owned catalog payload that can be committed to the local store atomically.
struct SystemCatalogSnapshot: Equatable, Sendable {
    let entries: [ProgramCatalogEntry]
    let workoutDays: [WorkoutDay]
    let dayExercises: [WorkoutDayExercise]
    let exercises: [Exercise]
}
