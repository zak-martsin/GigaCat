import Foundation

/// In-memory catalog repository that combines programs with lightweight discovery metadata.
struct MockProgramCatalogRepository: ProgramCatalogRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry] {
        let programs = await store.programs()
        let metadataByProgramID = await store.programCatalogMetadataByProgramID()

        return programs.map { program in
            let metadata = metadataByProgramID[program.id] ?? ProgramCatalogMetadata()

            return ProgramCatalogEntry(
                program: program,
                isRecommended: metadata.isRecommended,
                isPopular: metadata.isPopular,
                rateScore: metadata.rateScore
            )
        }
    }
}
