import Foundation
import Testing
@testable import GigaCat

@MainActor
struct CatalogViewModelTests {
    @Test
    func loadsDefaultCatalogAndFiltersByAvailableTags() async throws {
        let factory = try MockRepositoryFactory()
        let viewModel = makeViewModel(factory: factory)

        await viewModel.load()
        viewModel.selectFilter(.tag(.strength))

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.availableFilters.contains(.tag(.strength)))
        #expect(Set(viewModel.visiblePrograms.map(\.title)) == [
            "Сплит для мужчин",
            "Сплит для женщин"
        ])
    }

    @Test
    func selectingPresentedProgramEmitsSelectedProgramChange() async throws {
        let factory = try MockRepositoryFactory()
        var changes: [AppDataChange] = []
        let viewModel = makeViewModel(
            factory: factory,
            onDataChanged: { changes.append($0) }
        )

        await viewModel.load()
        let selectedItem = try #require(
            viewModel.programs.first { $0.isSelected }
        )
        await viewModel.presentProgramDetail(for: selectedItem)
        await viewModel.selectPresentedProgram()

        #expect(changes == [.selectedProgram])
        #expect(viewModel.presentedProgramDetail == nil)
        #expect(viewModel.programs.first(where: { $0.id == selectedItem.id })?.isSelected == true)
    }

    private func makeViewModel(
        factory: MockRepositoryFactory,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) -> CatalogViewModel {
        CatalogViewModel(
            userRepository: factory.userRepository,
            defaultProgramCatalogRepository: factory.defaultProgramCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository,
            onDataChanged: onDataChanged
        )
    }
}
