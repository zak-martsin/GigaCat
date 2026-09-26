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

    @Test
    func loadsArtworkForVisibleProgram() async throws {
        let factory = try MockRepositoryFactory()
        let expectedURL = URL(fileURLWithPath: "/cached/revision-1.jpg")
        let artworkService = CatalogProgramArtworkServiceSpy(fileURL: expectedURL)
        let viewModel = makeViewModel(
            factory: factory,
            programArtworkService: artworkService
        )

        await viewModel.load()
        let item = try #require(viewModel.programs.first { $0.artwork != nil })
        let artwork = try #require(item.artwork)
        await viewModel.loadArtwork(for: item.id)

        #expect(
            viewModel.programs.first(where: { $0.id == item.id })?.artworkFileURL
                == expectedURL
        )
        #expect(
            await artworkService.lastRequest()
                == CatalogProgramArtworkServiceSpy.Request(
                    programID: item.id,
                    artwork: artwork
                )
        )
    }

    @Test
    func preservesLoadedArtworkWhenCatalogReloadsSameRevision() async throws {
        let factory = try MockRepositoryFactory()
        let expectedURL = URL(fileURLWithPath: "/cached/revision-1.jpg")
        let viewModel = makeViewModel(
            factory: factory,
            programArtworkService: CatalogProgramArtworkServiceSpy(fileURL: expectedURL)
        )

        await viewModel.load()
        let item = try #require(viewModel.programs.first { $0.artwork != nil })
        await viewModel.loadArtwork(for: item.id)
        await viewModel.load()

        #expect(
            viewModel.programs.first(where: { $0.id == item.id })?.artworkFileURL
                == expectedURL
        )
    }

    private func makeViewModel(
        factory: MockRepositoryFactory,
        programArtworkService: any ProgramArtworkServicing = CatalogProgramArtworkServiceSpy(),
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) -> CatalogViewModel {
        CatalogViewModel(
            userRepository: factory.userRepository,
            defaultProgramCatalogRepository: factory.defaultProgramCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository,
            programArtworkService: programArtworkService,
            onDataChanged: onDataChanged
        )
    }
}

private actor CatalogProgramArtworkServiceSpy: ProgramArtworkServicing {
    struct Request: Equatable, Sendable {
        let programID: UUID
        let artwork: ProgramArtwork
    }

    private let resolvedFileURL: URL
    private var requests: [Request] = []

    init(fileURL: URL = URL(fileURLWithPath: "/cached/program.jpg")) {
        resolvedFileURL = fileURL
    }

    func fileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) async throws -> URL {
        requests.append(Request(programID: programID, artwork: artwork))
        return resolvedFileURL
    }

    func lastRequest() -> Request? {
        requests.last
    }
}
