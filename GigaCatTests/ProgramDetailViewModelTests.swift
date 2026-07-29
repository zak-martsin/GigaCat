import Testing
@testable import GigaCat

@MainActor
struct ProgramDetailViewModelTests {
    @Test
    func presentsRepositoryBackedDetailForGlobalMiniPlayer() async throws {
        let factory = MockRepositoryFactory()
        let user = try #require(try await factory.userRepository.currentUser())
        let programID = try #require(user.selectedProgramId)
        let viewModel = ProgramDetailViewModel(
            userRepository: factory.userRepository,
            libraryRepository: factory.workoutProgramLibraryRepository,
            service: ProgramDetailService(
                userRepository: factory.userRepository,
                programCatalogRepository: factory.programCatalogRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            )
        )

        await viewModel.present(programID: programID)

        #expect(viewModel.presentedDetail?.id == programID)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func savesPresentedProgramAndNotifiesLibrary() async throws {
        let factory = MockRepositoryFactory()
        let user = try #require(try await factory.userRepository.currentUser())
        let catalog = try await factory.programCatalogRepository.fetchProgramCatalog()
        let savedPrograms = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)
        let savedIDs = Set(savedPrograms.map(\.id))
        let program = try #require(catalog.map(\.program).first { !savedIDs.contains($0.id) })
        var changes: [AppDataChange] = []
        let viewModel = ProgramDetailViewModel(
            userRepository: factory.userRepository,
            libraryRepository: factory.workoutProgramLibraryRepository,
            service: ProgramDetailService(
                userRepository: factory.userRepository,
                programCatalogRepository: factory.programCatalogRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            ),
            onDataChanged: { changes.append($0) }
        )

        await viewModel.present(programID: program.id)
        await viewModel.addPresentedProgramToLibrary()

        let updatedPrograms = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)
        #expect(updatedPrograms.contains { $0.id == program.id })
        #expect(changes == [.library])
        #expect(viewModel.presentedDetail == nil)
    }
}
