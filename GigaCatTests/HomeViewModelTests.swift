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
            libraryRepository: factory.workoutProgramLibraryRepository,
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
            libraryRepository: factory.workoutProgramLibraryRepository,
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

    @Test
    func addingCatalogProgramSavesItAndEmitsLibraryChange() async throws {
        let factory = MockRepositoryFactory()
        var changes: [AppDataChange] = []
        let viewModel = HomeViewModel(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            libraryRepository: factory.workoutProgramLibraryRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository,
            onDataChanged: { changes.append($0) }
        )

        await viewModel.load()
        let user = try #require(viewModel.profileUser)
        let savedPrograms = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)
        let savedIDs = Set(savedPrograms.map(\.id))
        let program = try #require(viewModel.allPrograms.first { !savedIDs.contains($0.id) })

        await viewModel.presentProgramDetail(for: program)
        #expect(viewModel.presentedProgramDetail?.isSavedToLibrary == false)
        await viewModel.addPresentedProgramToLibrary()

        let updatedPrograms = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)
        #expect(updatedPrograms.contains { $0.id == program.id })
        #expect(changes == [.library])
        #expect(viewModel.presentedProgramDetail?.isSavedToLibrary == true)

        await viewModel.removePresentedProgramFromLibrary()

        let programsAfterRemoval = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)
        #expect(!programsAfterRemoval.contains { $0.id == program.id })
        #expect(changes == [.library, .library])
        #expect(viewModel.presentedProgramDetail?.isSavedToLibrary == false)
    }

}
