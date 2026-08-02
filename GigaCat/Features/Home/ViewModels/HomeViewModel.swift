import Combine
import Foundation

@MainActor
/// Screen state and user action coordinator for the Home feature.
final class HomeViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var allPrograms: [ProgramSectionItem] = []
    @Published var selectedProgram: SelectedProgramSummary?
    @Published var selectedTag: ProgramFilterTag = .all
    @Published var presentedProgramDetail: ProgramDetail?
    @Published var programSelectionConflictAlert: ProgramSelectionConflictAlert?
    @Published var isSearchPresented = false
    @Published var searchQuery = ""

    // MARK: - Dependencies

    private let userRepository: UserRepository
    private let programCatalogRepository: ProgramCatalogRepository
    private let libraryRepository: WorkoutProgramLibraryRepository
    private let discoveryService: HomeProgramDiscoveryServicing
    private let presentationService: HomePresentationServicing
    private let programDetailService: ProgramDetailServicing
    private let onDataChanged: AppDataChangeHandler
    private var loadTracker = DataLoadTracker()
    private var currentUser: User?
    private var pendingProgramSelectionID: UUID?

    // MARK: - Initialization

    init(
        userRepository: UserRepository,
        programCatalogRepository: ProgramCatalogRepository,
        libraryRepository: WorkoutProgramLibraryRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        discoveryService: HomeProgramDiscoveryServicing = HomeProgramDiscoveryService(),
        presentationService: HomePresentationServicing? = nil,
        programDetailService: ProgramDetailServicing? = nil,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.userRepository = userRepository
        self.programCatalogRepository = programCatalogRepository
        self.libraryRepository = libraryRepository
        self.discoveryService = discoveryService
        self.presentationService = presentationService ?? HomePresentationService(
            workoutProgramRepository: workoutProgramRepository,
            workoutRepository: workoutRepository
        )
        self.programDetailService = programDetailService ?? ProgramDetailService(
            userRepository: userRepository,
            programCatalogRepository: programCatalogRepository,
            libraryRepository: libraryRepository,
            workoutProgramRepository: workoutProgramRepository,
            workoutRepository: workoutRepository
        )
        self.onDataChanged = onDataChanged
    }

    // MARK: - Derived State

    var recommendedPrograms: [ProgramSectionItem] {
        allPrograms.filter(\.isRecommended)
    }

    var popularPrograms: [ProgramSectionItem] {
        allPrograms.filter(\.isPopular)
    }

    var profileUser: User? {
        currentUser
    }

    var availableTags: [ProgramFilterTag] {
        discoveryService.availableTags(in: allPrograms)
    }

    var isShowingTagResults: Bool {
        selectedTag != .all
    }

    var tagFilteredPrograms: [ProgramSectionItem] {
        discoveryService.programs(in: allPrograms, matching: selectedTag)
    }

    var searchResults: [ProgramSectionItem] {
        discoveryService.searchResults(for: searchQuery, in: allPrograms)
    }

    // MARK: - Loading

    /// Prevents repeated first-load work when the screen is revisited within the same lifecycle.
    func loadIfNeeded() async {
        guard loadTracker.needsLoading else { return }
        await load()
    }

    /// Marks cached Home presentation as stale so the next entry reloads repository state.
    func invalidate() {
        loadTracker.invalidate()
    }

    /// Reloads Home catalog and selected-program presentation from repositories.
    func load() async {
        guard !isLoading else { return }

        let loadingRevision = loadTracker.currentRevision
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await userRepository.currentUser()
            currentUser = user

            guard let user else {
                errorMessage = "No active user was found."
                return
            }

            let catalog = try await programCatalogRepository.fetchProgramCatalog()
            let selectedProgramID = user.selectedProgramId
            let items = try await presentationService.makeProgramItems(
                from: catalog,
                selectedProgramID: selectedProgramID
            )

            allPrograms = items
            selectedProgram = try await presentationService.makeSelectedProgramSummary(
                selectedProgramID: selectedProgramID,
                catalog: catalog,
                user: user
            )

            loadTracker.markLoaded(revision: loadingRevision)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Program Presentation

    /// Tries to switch the selected program, or surfaces a conflict when an unfinished session blocks the change.
    func selectProgram(id: UUID) async {
        guard let user = currentUser else { return }

        do {
            let result = try await programDetailService.selectProgram(id, for: user)

            switch result {
            case let .switched(updatedUser):
                currentUser = updatedUser
                await onDataChanged(.selectedProgram)
                await load()
            case let .blocked(pendingProgramID, alert):
                pendingProgramSelectionID = pendingProgramID
                programSelectionConflictAlert = alert
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Builds the detail sheet model for a program card or row selected on Home.
    func presentProgramDetail(for item: ProgramSectionItem) async {
        guard let currentUser else { return }

        do {
            presentedProgramDetail = try await programDetailService.makeDetail(
                for: item.id,
                user: currentUser
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func presentSelectedProgramDetail() async {
        guard let selectedProgram else { return }
        guard let item = allPrograms.first(where: { $0.id == selectedProgram.id }) else { return }
        await presentProgramDetail(for: item)
    }

    func dismissProgramDetail() {
        presentedProgramDetail = nil
    }

    func selectPresentedProgram() async {
        guard let presentedProgramDetail else { return }
        await selectProgram(id: presentedProgramDetail.id)
        dismissProgramDetail()
    }

    func continueProgramSelectionConflict() -> MiniPlayerRoute {
        pendingProgramSelectionID = nil
        programSelectionConflictAlert = nil
        return .openWorkout
    }

    func cancelProgramSelectionConflict() {
        pendingProgramSelectionID = nil
        programSelectionConflictAlert = nil
    }

    // MARK: - Session Actions

    func completeActiveSessionAndSelectPendingProgram() async {
        await resolveProgramSelectionConflict(using: .finishSession)
    }

    func cancelActiveSessionAndSelectPendingProgram() async {
        await resolveProgramSelectionConflict(using: .cancelSession)
    }

    func addPresentedProgramToLibrary() async {
        guard let detail = presentedProgramDetail,
              !detail.isSavedToLibrary,
              let currentUser else {
            return
        }

        do {
            try await libraryRepository.saveProgram(detail.id, for: currentUser.id)
            presentedProgramDetail?.isSavedToLibrary = true
            await onDataChanged(.library)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePresentedProgramFromLibrary() async {
        guard let detail = presentedProgramDetail,
              detail.isSavedToLibrary,
              let currentUser else {
            return
        }

        do {
            try await libraryRepository.removeProgram(detail.id, for: currentUser.id)
            presentedProgramDetail?.isSavedToLibrary = false
            await onDataChanged(.library)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completePresentedProgramSession() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let didComplete = try await programDetailService.completeActiveSession(
                for: detail.id,
                userID: currentUser.id
            )
            guard didComplete else { return }
            dismissProgramDetail()
            await onDataChanged(.workoutSession)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePresentedProgramSession() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let didCancel = try await programDetailService.cancelActiveSession(
                for: detail.id,
                userID: currentUser.id
            )
            guard didCancel else { return }
            dismissProgramDetail()
            await onDataChanged(.workoutSession)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search and Filters

    func selectTag(_ tag: ProgramFilterTag) {
        selectedTag = tag
    }

    func presentSearch() {
        searchQuery = ""
        isSearchPresented = true
    }

    func dismissSearch() {
        isSearchPresented = false
        searchQuery = ""
    }

    // MARK: - Private Helpers

    private func resolveProgramSelectionConflict(
        using resolution: ProgramDetailConflictResolution
    ) async {
        guard let pendingProgramSelectionID,
              let currentUser else {
            return
        }

        do {
            let updatedUser = try await programDetailService.resolveSelectionConflict(
                selecting: pendingProgramSelectionID,
                for: currentUser,
                resolution: resolution
            )
            self.currentUser = updatedUser
            cancelProgramSelectionConflict()
            dismissProgramDetail()
            await onDataChanged(.selectedProgram)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
