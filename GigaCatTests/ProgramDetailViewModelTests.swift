import Testing
@testable import GigaCat

@MainActor
struct ProgramDetailViewModelTests {
    @Test
    func presentsRepositoryBackedDetailForGlobalMiniPlayer() async throws {
        let factory = try MockRepositoryFactory()
        let user = try #require(try await factory.userRepository.currentUser())
        let programID = try #require(user.selectedProgramId)
        let viewModel = ProgramDetailViewModel(
            userRepository: factory.userRepository,
            service: ProgramDetailService(
                userRepository: factory.userRepository,
                defaultProgramCatalogRepository: factory.defaultProgramCatalogRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            )
        )

        await viewModel.present(programID: programID)

        #expect(viewModel.presentedDetail?.id == programID)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func selectingPresentedProgramNotifiesApplication() async throws {
        let factory = try MockRepositoryFactory()
        let user = try #require(try await factory.userRepository.currentUser())
        let programID = try #require(user.selectedProgramId)
        var changes: [AppDataChange] = []
        let viewModel = ProgramDetailViewModel(
            userRepository: factory.userRepository,
            service: ProgramDetailService(
                userRepository: factory.userRepository,
                defaultProgramCatalogRepository: factory.defaultProgramCatalogRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            ),
            onDataChanged: { changes.append($0) }
        )

        await viewModel.present(programID: programID)
        await viewModel.selectPresentedProgram()

        #expect(changes == [.selectedProgram])
        #expect(viewModel.presentedDetail == nil)
    }
}
