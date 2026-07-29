import Foundation
import Testing
@testable import GigaCat

@MainActor
struct LibraryViewModelTests {

    @Test
    func loadReturnsTheSeededSavedProgramWithoutChangingSelection() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = makeViewModel(factory: factory)
        let selectedProgramID = try #require(
            try await factory.userRepository.currentUser()?.selectedProgramId
        )

        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.programs.map(\.title) == ["Strength Essentials"])
        #expect(viewModel.programs.first?.id != selectedProgramID)
    }

    @Test
    func removingProgramOnlyRemovesItsLibraryMembership() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = makeViewModel(factory: factory)
        let user = try #require(try await factory.userRepository.currentUser())
        let originalSelectedProgramID = user.selectedProgramId

        await viewModel.load()
        let savedProgram = try #require(viewModel.programs.first)
        await viewModel.removeProgram(savedProgram.id)

        let reloadedUser = try #require(try await factory.userRepository.currentUser())
        let catalogProgram = try await factory.workoutProgramRepository.fetchProgram(id: savedProgram.id)
        let savedPrograms = try await factory.workoutProgramLibraryRepository.fetchSavedPrograms(for: user.id)

        #expect(viewModel.loadState == .empty)
        #expect(viewModel.programs.isEmpty)
        #expect(savedPrograms.isEmpty)
        #expect(catalogProgram == savedProgram)
        #expect(reloadedUser.selectedProgramId == originalSelectedProgramID)
    }

    @Test
    func tappingSavedProgramBuildsTheSharedProgramDetail() async throws {
        let factory = MockRepositoryFactory()
        let viewModel = makeViewModel(factory: factory)

        await viewModel.load()
        let savedProgram = try #require(viewModel.programs.first)
        await viewModel.presentProgramDetail(for: savedProgram.id)

        let detail = try #require(viewModel.presentedProgramDetail)
        #expect(detail.id == savedProgram.id)
        #expect(detail.title == "Strength Essentials")
        #expect(detail.dayCount == 3)
        #expect(detail.exerciseCount == 4)
        #expect(detail.primaryAction == .chooseProgram)
        #expect(!detail.hasActiveSession)
    }

    @Test
    func choosingSavedProgramCanCancelActiveSessionAndSwitchSelection() async throws {
        let factory = MockRepositoryFactory()
        var changeNotificationCount = 0
        let viewModel = makeViewModel(factory: factory) {
            changeNotificationCount += 1
        }

        await viewModel.load()
        let savedProgram = try #require(viewModel.programs.first)
        await viewModel.presentProgramDetail(for: savedProgram.id)
        await viewModel.selectPresentedProgram()

        #expect(viewModel.presentedProgramDetail == nil)
        #expect(viewModel.programSelectionConflictAlert != nil)

        await viewModel.cancelActiveSessionAndSelectPendingProgram()

        let user = try #require(try await factory.userRepository.currentUser())
        let activeSession = try await factory.workoutRepository.activeSession(for: user.id)
        #expect(user.selectedProgramId == savedProgram.id)
        #expect(activeSession == nil)
        #expect(viewModel.programSelectionConflictAlert == nil)
        #expect(changeNotificationCount == 1)
    }

    private func makeViewModel(
        factory: MockRepositoryFactory,
        onProgramDataChanged: @escaping @MainActor () -> Void = {}
    ) -> LibraryViewModel {
        let detailService = ProgramDetailService(
            userRepository: factory.userRepository,
            programCatalogRepository: factory.programCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository
        )

        return LibraryViewModel(
            userRepository: factory.userRepository,
            libraryRepository: factory.workoutProgramLibraryRepository,
            programDetailService: detailService,
            onProgramDataChanged: onProgramDataChanged
        )
    }
}
