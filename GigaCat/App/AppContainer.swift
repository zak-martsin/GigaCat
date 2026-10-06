import Foundation

/// Reports completed local changes without exposing synchronization storage to the UI.
struct ForegroundRefreshResult: Equatable, Sendable {
    let didChange: Bool
    let selectedProgramBecameUnavailable: Bool
}

/// Owns the application-scoped feature graph and keeps dependency construction out of SwiftUI views.
@MainActor
final class AppContainer {
    let catalogViewModel: CatalogViewModel
    let progressViewModel: ProgressViewModel
    let workoutViewModel: WorkoutViewModel
    let programDetailViewModel: ProgramDetailViewModel
    private let dataChangeCoordinator: AppDataChangeCoordinator
    private let dataChangeDispatcher: AppDataChangeDispatcher
    private let userRepository: any UserRepository
    private let profileBootstrapper: any ProfileBootstrapping
    private let syncCoordinator: any SyncCoordinating
    private let systemCatalogSynchronizer: any SystemCatalogSyncing
    private let artworkService: any ArtworkServicing
    private let selectedProgramReconciler: SelectedProgramReconciliationService
    private var foregroundRefreshTask: Task<ForegroundRefreshResult, Never>?

    // The composition root keeps the complete dependency graph visible in one place.
    // swiftlint:disable:next function_body_length
    init(
        repositoryFactory: some RepositoryFactory,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        artworkService: any ArtworkServicing,
        profileBootstrapper: any ProfileBootstrapping
    ) {
        let dataChangeDispatcher = AppDataChangeDispatcher()
        let programDetailService = ProgramDetailService(
            userRepository: repositoryFactory.userRepository,
            defaultProgramCatalogRepository: repositoryFactory.defaultProgramCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let programDetailViewModel = ProgramDetailViewModel(
            userRepository: repositoryFactory.userRepository,
            service: programDetailService,
            artworkService: artworkService,
            onDataChanged: dataChangeDispatcher.send
        )
        let catalogViewModel = CatalogViewModel(
            userRepository: repositoryFactory.userRepository,
            defaultProgramCatalogRepository: repositoryFactory.defaultProgramCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository,
            artworkService: artworkService,
            programDetailService: programDetailService,
            onDataChanged: dataChangeDispatcher.send
        )
        let progressHistoryService = ProgressHistoryService(
            userRepository: repositoryFactory.userRepository,
            workoutRepository: repositoryFactory.workoutRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository
        )
        let progressViewModel = ProgressViewModel(
            historyService: progressHistoryService
        )
        let workoutContextService = WorkoutContextService(
            userRepository: repositoryFactory.userRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let workoutViewModel = WorkoutViewModel(
            contextService: workoutContextService,
            workoutRepository: repositoryFactory.workoutRepository,
            artworkService: artworkService,
            onDataChanged: dataChangeDispatcher.send
        )
        let dataChangeCoordinator = AppDataChangeCoordinator(
            invalidateCatalog: { [weak catalogViewModel] in
                catalogViewModel?.invalidate()
            },
            invalidateProgress: { [weak progressViewModel] in
                progressViewModel?.invalidate()
            },
            invalidateWorkout: { [weak workoutViewModel] in
                workoutViewModel?.invalidate()
            },
            requestProfileSync: {
                // Local mutations update the UI immediately; their cloud push remains best-effort.
                Task(priority: .utility) {
                    await syncCoordinator.requestSync()
                }
            }
        )

        self.catalogViewModel = catalogViewModel
        self.progressViewModel = progressViewModel
        self.workoutViewModel = workoutViewModel
        self.programDetailViewModel = programDetailViewModel
        self.dataChangeCoordinator = dataChangeCoordinator
        self.dataChangeDispatcher = dataChangeDispatcher
        self.userRepository = repositoryFactory.userRepository
        self.profileBootstrapper = profileBootstrapper
        self.syncCoordinator = syncCoordinator
        self.systemCatalogSynchronizer = systemCatalogSynchronizer
        self.artworkService = artworkService
        selectedProgramReconciler = SelectedProgramReconciliationService(
            userRepository: repositoryFactory.userRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository
        )

        dataChangeDispatcher.install(handler: dataChangeCoordinator.handle)
    }

    /// Shares an ordered foreground pass between startup and active-scene requests.
    func refreshAfterBecomingActive(for userID: UUID) async -> ForegroundRefreshResult {
        if let foregroundRefreshTask {
            return await foregroundRefreshTask.value
        }

        let task = Task { await performForegroundRefresh(for: userID) }
        foregroundRefreshTask = task
        let result = await task.value
        foregroundRefreshTask = nil
        return result
    }

    private func performForegroundRefresh(for userID: UUID) async -> ForegroundRefreshResult {
        let selectedProgramBefore = try? await userRepository
            .user(id: userID)?.selectedProgramId
        let catalogDidChange: Bool
        let catalogWasRefreshed: Bool
        do {
            catalogDidChange = try await systemCatalogSynchronizer.refreshSystemCatalog()
            catalogWasRefreshed = true
        } catch {
            // An unsuccessful download is not evidence that a selected program disappeared.
            catalogDidChange = false
            catalogWasRefreshed = false
        }

        let selectionWasReconciled = catalogWasRefreshed
            ? ((try? await selectedProgramReconciler.clearUnavailableSelection(for: userID)) ?? false)
            : false

        await syncCoordinator.requestSync()

        let profileDidChange = (
            try? await profileBootstrapper.refreshProfile(for: userID)
        ) ?? false
        let selectedProgramAfter = try? await userRepository
            .user(id: userID)?.selectedProgramId

        if catalogDidChange {
            await dataChangeDispatcher.send(.programCatalog)
        }
        if selectedProgramBefore != selectedProgramAfter {
            await dataChangeDispatcher.send(.selectedProgram)
        }

        return ForegroundRefreshResult(
            didChange: catalogDidChange || selectionWasReconciled || profileDidChange,
            selectedProgramBecameUnavailable: selectionWasReconciled
        )
    }
}
