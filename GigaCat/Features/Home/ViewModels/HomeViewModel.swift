import Combine
import Foundation

@MainActor
/// Screen state and user action coordinator for the Home feature.
final class HomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var allPrograms: [ProgramSectionItem] = []
    @Published var selectedProgram: SelectedProgramSummary?
    @Published var miniPlayerState = MiniPlayerState(
        title: "No Program Selected",
        subtitle: "Choose a program to start training.",
        action: .none
    )
    @Published var selectedTag: ProgramFilterTag = .all
    @Published var presentedProgramDetail: ProgramDetail?
    @Published var expiredSessionAlert: ExpiredSessionAlert?
    @Published var programSelectionConflictAlert: ProgramSelectionConflictAlert?
    @Published var isSearchPresented = false
    @Published var searchQuery = ""

    private let userRepository: UserRepository
    private let homeRepository: HomeRepository
    private let discoveryService: HomeProgramDiscoveryServicing
    private let presentationService: HomePresentationServicing
    private let sessionCoordinator: HomeSessionCoordinating
    private var hasLoaded = false
    private var currentUser: User?
    private var miniPlayerContext: MiniPlayerContext = .noProgramSelected
    private var pendingProgramSelectionID: UUID?
    private let sessionExpirationInterval: TimeInterval = 60 * 60 * 8

    init(
        userRepository: UserRepository,
        homeRepository: HomeRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        discoveryService: HomeProgramDiscoveryServicing = HomeProgramDiscoveryService(),
        presentationService: HomePresentationServicing? = nil,
        alertBuilder: HomeAlertBuilding = HomeAlertBuilder(),
        sessionCoordinator: HomeSessionCoordinating? = nil
    ) {
        self.userRepository = userRepository
        self.homeRepository = homeRepository
        self.discoveryService = discoveryService
        self.presentationService = presentationService ?? HomePresentationService(
            workoutProgramRepository: workoutProgramRepository,
            workoutRepository: workoutRepository
        )
        self.sessionCoordinator = sessionCoordinator ?? HomeSessionCoordinator(
            userRepository: userRepository,
            workoutRepository: workoutRepository,
            alertBuilder: alertBuilder
        )
    }

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

    /// Prevents repeated first-load work when the screen is revisited within the same lifecycle.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Reloads all Home content, selected program presentation, and mini player state from repositories.
    func load() async {
        guard !isLoading else { return }

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

            let catalog = try await homeRepository.fetchProgramCatalog()
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

            let programs = catalog.map(\.program)
            let miniPlayerPresentation = try await presentationService.makeMiniPlayerPresentation(
                user: user,
                selectedProgramID: selectedProgramID,
                programs: programs,
                sessionExpirationInterval: sessionExpirationInterval
            )
            miniPlayerState = miniPlayerPresentation.state
            miniPlayerContext = miniPlayerPresentation.context
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Tries to switch the selected program, or surfaces a conflict when an unfinished session blocks the change.
    func selectProgram(id: UUID) async {
        guard let user = currentUser else { return }

        do {
            let result = try await sessionCoordinator.selectProgram(
                id: id,
                currentUser: user,
                miniPlayerContext: miniPlayerContext
            )

            switch result {
            case let .switched(updatedUser):
                currentUser = updatedUser
                hasLoaded = false
                await load()
            case let .blocked(pendingProgramSelectionID, alert):
                self.pendingProgramSelectionID = pendingProgramSelectionID
                programSelectionConflictAlert = alert
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Builds the detail sheet model for a program card or row selected on Home.
    func presentProgramDetail(for item: ProgramSectionItem) async {
        do {
            presentedProgramDetail = try await presentationService.makeProgramDetail(
                for: item,
                selectedProgram: selectedProgram,
                miniPlayerContext: miniPlayerContext
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

    /// Resolves mini player behavior, including the expired-session case that needs an alert instead of navigation.
    func handleMiniPlayerAction() async -> MiniPlayerRoute {
        let result = sessionCoordinator.handleMiniPlayerAction(
            currentUser: currentUser,
            miniPlayerContext: miniPlayerContext
        )
        expiredSessionAlert = result.expiredSessionAlert
        return result.route
    }

    func continueExpiredSession() async -> MiniPlayerRoute {
        expiredSessionAlert = nil
        return .openWorkout
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

    func completeExpiredSession() async {
        do {
            let result = try await sessionCoordinator.completeExpiredSession(
                miniPlayerContext: miniPlayerContext
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeActiveSessionAndSelectPendingProgram() async {
        do {
            let result = try await sessionCoordinator.completeActiveSessionAndSelectPendingProgram(
                miniPlayerContext: miniPlayerContext,
                pendingProgramSelectionID: pendingProgramSelectionID,
                currentUser: currentUser
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelActiveSessionAndSelectPendingProgram() async {
        do {
            let result = try await sessionCoordinator.cancelActiveSessionAndSelectPendingProgram(
                miniPlayerContext: miniPlayerContext,
                pendingProgramSelectionID: pendingProgramSelectionID,
                currentUser: currentUser
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPresentedProgramToLibrary() {
        guard let presentedProgramDetail else { return }
        print("Add program to library: \(presentedProgramDetail.title)")
    }

    func completePresentedProgramSession() async {
        do {
            let result = try await sessionCoordinator.completePresentedProgramSession(
                presentedProgramDetail: presentedProgramDetail,
                miniPlayerContext: miniPlayerContext,
                selectedProgram: selectedProgram
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePresentedProgramSession() async {
        do {
            let result = try await sessionCoordinator.deletePresentedProgramSession(
                presentedProgramDetail: presentedProgramDetail,
                miniPlayerContext: miniPlayerContext,
                selectedProgram: selectedProgram
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteExpiredSession() async {
        do {
            let result = try await sessionCoordinator.deleteExpiredSession(
                miniPlayerContext: miniPlayerContext
            )
            await apply(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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

    // MARK: - Session Mutation Handling

    /// Applies a session mutation result back into Home state so view logic stays simple and declarative.
    private func apply(_ result: HomeSessionMutationResult) async {
        if let updatedUser = result.updatedUser {
            currentUser = updatedUser
        }
        if result.clearedExpiredSessionAlert {
            expiredSessionAlert = nil
        }
        if result.clearedProgramSelectionConflictAlert {
            programSelectionConflictAlert = nil
        }
        if result.clearedPendingProgramSelectionID {
            pendingProgramSelectionID = nil
        }
        if result.shouldDismissProgramDetail {
            dismissProgramDetail()
        }
        if result.shouldReload {
            hasLoaded = false
            await load()
        }
    }
}
