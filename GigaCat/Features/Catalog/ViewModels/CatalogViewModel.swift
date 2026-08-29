import Combine
import Foundation

/// Screen state and user actions for the default-program catalog.
@MainActor
final class CatalogViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var programs: [CatalogProgramItem] = []
    @Published var selectedFilter: CatalogFilter = .all
    @Published var presentedProgramDetail: ProgramDetail?
    @Published var programSelectionConflictAlert: ProgramSelectionConflictAlert?
    @Published var errorMessage: String?

    private let userRepository: UserRepository
    private let defaultProgramCatalogRepository: DefaultProgramCatalogRepository
    private let presentationService: CatalogPresentationServicing
    private let programDetailService: ProgramDetailServicing
    private let onDataChanged: AppDataChangeHandler
    private var loadTracker = DataLoadTracker()
    private var currentUser: User?
    private var pendingProgramSelectionID: UUID?

    init(
        userRepository: UserRepository,
        defaultProgramCatalogRepository: DefaultProgramCatalogRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        presentationService: CatalogPresentationServicing? = nil,
        programDetailService: ProgramDetailServicing? = nil,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.userRepository = userRepository
        self.defaultProgramCatalogRepository = defaultProgramCatalogRepository
        self.presentationService = presentationService ?? CatalogPresentationService(
            workoutProgramRepository: workoutProgramRepository
        )
        self.programDetailService = programDetailService ?? ProgramDetailService(
            userRepository: userRepository,
            defaultProgramCatalogRepository: defaultProgramCatalogRepository,
            workoutProgramRepository: workoutProgramRepository,
            workoutRepository: workoutRepository
        )
        self.onDataChanged = onDataChanged
    }

    var profileUser: User? {
        currentUser
    }

    var availableFilters: [CatalogFilter] {
        presentationService.availableFilters(in: programs)
    }

    var visiblePrograms: [CatalogProgramItem] {
        presentationService.items(in: programs, matching: selectedFilter)
    }

    func loadIfNeeded() async {
        guard loadTracker.needsLoading else { return }
        await load()
    }

    func invalidate() {
        loadTracker.invalidate()
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        repeat {
            let loadingRevision = loadTracker.currentRevision
            errorMessage = nil

            do {
                guard let user = try await userRepository.currentUser() else {
                    errorMessage = "No active user was found."
                    return
                }

                currentUser = user
                let catalog = try await defaultProgramCatalogRepository.fetchProgramCatalog()
                programs = try await presentationService.makeItems(
                    from: catalog,
                    selectedProgramID: user.selectedProgramId
                )

                if !availableFilters.contains(selectedFilter) {
                    selectedFilter = .all
                }
                loadTracker.markLoaded(revision: loadingRevision)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } while loadTracker.needsLoading
    }

    func selectFilter(_ filter: CatalogFilter) {
        selectedFilter = filter
    }

    func presentProgramDetail(for item: CatalogProgramItem) async {
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

    func dismissProgramDetail() {
        presentedProgramDetail = nil
    }

    func selectPresentedProgram() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let result = try await programDetailService.selectProgram(detail.id, for: currentUser)
            dismissProgramDetail()

            switch result {
            case .switched(let updatedUser):
                self.currentUser = updatedUser
                await onDataChanged(.selectedProgram)
                await load()
            case .blocked(let programID, let alert):
                pendingProgramSelectionID = programID
                programSelectionConflictAlert = alert
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completePresentedProgramSession() async {
        await mutatePresentedSession(using: programDetailService.completeActiveSession)
    }

    func cancelPresentedProgramSession() async {
        await mutatePresentedSession(using: programDetailService.cancelActiveSession)
    }

    func finishSessionAndSelectPendingProgram() async {
        await resolveSelectionConflict(using: .finishSession)
    }

    func cancelSessionAndSelectPendingProgram() async {
        await resolveSelectionConflict(using: .cancelSession)
    }

    func cancelSelectionConflict() {
        pendingProgramSelectionID = nil
        programSelectionConflictAlert = nil
    }

    private func mutatePresentedSession(
        using mutation: (UUID, UUID) async throws -> Bool
    ) async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            guard try await mutation(detail.id, currentUser.id) else { return }
            dismissProgramDetail()
            await onDataChanged(.workoutSession)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveSelectionConflict(
        using resolution: ProgramDetailConflictResolution
    ) async {
        guard let pendingProgramSelectionID,
              let currentUser else {
            return
        }

        do {
            self.currentUser = try await programDetailService.resolveSelectionConflict(
                selecting: pendingProgramSelectionID,
                for: currentUser,
                resolution: resolution
            )
            cancelSelectionConflict()
            await onDataChanged(.selectedProgram)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
