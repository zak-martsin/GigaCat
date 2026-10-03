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
            artworkService: artworkService
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
                    owner: .program(item.id),
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
            artworkService: CatalogProgramArtworkServiceSpy(fileURL: expectedURL)
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
        artworkService: any ArtworkServicing = CatalogProgramArtworkServiceSpy(),
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) -> CatalogViewModel {
        CatalogViewModel(
            userRepository: factory.userRepository,
            defaultProgramCatalogRepository: factory.defaultProgramCatalogRepository,
            workoutProgramRepository: factory.workoutProgramRepository,
            workoutRepository: factory.workoutRepository,
            artworkService: artworkService,
            onDataChanged: onDataChanged
        )
    }
}

private actor CatalogProgramArtworkServiceSpy: ArtworkServicing {
    struct Request: Equatable, Sendable {
        let owner: ArtworkOwner
        let artwork: ArtworkReference
    }

    private let resolvedFileURL: URL
    private var requests: [Request] = []

    init(fileURL: URL = URL(fileURLWithPath: "/cached/program.jpg")) {
        resolvedFileURL = fileURL
    }

    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL {
        requests.append(Request(owner: owner, artwork: artwork))
        return resolvedFileURL
    }

    func lastRequest() -> Request? {
        requests.last
    }
}
