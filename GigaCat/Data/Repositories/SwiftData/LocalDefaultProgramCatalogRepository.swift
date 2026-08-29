import Foundation
import SwiftData

/// SwiftData-backed reader for shared, active default programs.
struct LocalDefaultProgramCatalogRepository: DefaultProgramCatalogRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry] {
        let programDescriptor = FetchDescriptor<WorkoutProgramEntity>(
            sortBy: [
                SortDescriptor(\.title)
            ]
        )
        let programEntities = try context.fetch(programDescriptor)

        return try programEntities
            .filter { $0.isActive && $0.authorId == nil }
            .map { entity in
                let program = try WorkoutProgramMapper.toDomain(entity)
                return ProgramCatalogEntry(program: program)
            }
    }
}
