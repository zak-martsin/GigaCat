import Foundation

/// In-memory default catalog repository used by previews and feature tests.
struct MockDefaultProgramCatalogRepository: DefaultProgramCatalogRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry] {
        let programs = await store.programs()
        return programs
            .filter { $0.isActive && $0.authorId == nil }
            .map(ProgramCatalogEntry.init)
    }
}
