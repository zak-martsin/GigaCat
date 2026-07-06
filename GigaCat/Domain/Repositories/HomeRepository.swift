import Foundation

/// Presentation-ready catalog entry for program discovery surfaces such as Home and search.
struct HomeProgramCatalogEntry: Identifiable, Equatable, Sendable {
    let program: WorkoutProgram
    let isRecommended: Bool
    let isPopular: Bool
    let rateScore: Double?

    var id: UUID {
        program.id
    }
}

/// Read-only access to curated program catalog data used by Home discovery flows.
protocol HomeRepository: Sendable {
    func fetchProgramCatalog() async throws -> [HomeProgramCatalogEntry]
}
