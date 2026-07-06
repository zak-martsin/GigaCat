import Foundation

/// In-memory home repository that combines the full program catalog with lightweight discovery metadata.
struct MockHomeRepository: HomeRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func fetchProgramCatalog() async throws -> [HomeProgramCatalogEntry] {
        let programs = await store.programs()
        let metadataByProgramID = await store.homeProgramCatalogMetadataByProgramID()

        return programs.map { program in
            let metadata = metadataByProgramID[program.id] ?? HomeProgramCatalogMetadata()

            return HomeProgramCatalogEntry(
                program: program,
                isRecommended: metadata.isRecommended,
                isPopular: metadata.isPopular,
                rateScore: metadata.rateScore
            )
        }
    }
}
