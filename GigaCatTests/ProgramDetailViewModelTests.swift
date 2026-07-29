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
}
