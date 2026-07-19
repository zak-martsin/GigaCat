import Foundation

/// Catalog entry that combines a workout program with discovery and recommendation metadata.
struct ProgramCatalogEntry: Identifiable, Equatable, Sendable {
    let program: WorkoutProgram
    let isRecommended: Bool
    let isPopular: Bool
    let rateScore: Double?

    var id: UUID {
        program.id
    }
}

/// Read-only access to the curated program catalog shared by discovery and workout entry flows.
protocol ProgramCatalogRepository: Sendable {
    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry]
}
