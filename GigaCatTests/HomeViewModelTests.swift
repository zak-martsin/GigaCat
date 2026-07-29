import Foundation
import Testing
@testable import GigaCat

@MainActor
struct HomeViewModelTests {

    @Test
    func tagFilteringUsesTheFullCatalog() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )

        await viewModel.load()
        viewModel.selectTag(.tag(.mobility))

        #expect(viewModel.availableTags.contains(.tag(.mobility)))
        #expect(viewModel.isShowingTagResults)
        #expect(Set(viewModel.tagFilteredPrograms.map(\.title)) == Set(["Conditioning Boost", "Mobility Reset"]))
    }

    @Test
    func searchMatchesTitleDescriptionAndTags() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )

        await viewModel.load()

        viewModel.searchQuery = "strength essentials"
        #expect(viewModel.searchResults.map(\.title) == ["Strength Essentials"])

        viewModel.searchQuery = "posture"
        #expect(viewModel.searchResults.map(\.title) == ["Mobility Reset"])

        viewModel.searchQuery = "hiit"
        #expect(viewModel.searchResults.map(\.title) == ["Conditioning Boost"])

        viewModel.searchQuery = "   "
        #expect(viewModel.searchResults.isEmpty)
    }

}
