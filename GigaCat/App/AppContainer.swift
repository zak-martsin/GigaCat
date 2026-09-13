import Foundation

/// Owns the application-scoped feature graph and keeps dependency construction out of SwiftUI views.
@MainActor
final class AppContainer {
    let catalogViewModel: CatalogViewModel
    let progressViewModel: ProgressViewModel
    let workoutViewModel: WorkoutViewModel
    let miniPlayerViewModel: MiniPlayerViewModel
    let programDetailViewModel: ProgramDetailViewModel
    private let dataChangeCoordinator: AppDataChangeCoordinator
    private let dataChangeDispatcher: AppDataChangeDispatcher
    private let userRepository: any UserRepository
    private let profileBootstrapper: any ProfileBootstrapping
    private let syncCoordinator: any SyncCoordinating
    private let systemCatalogSynchronizer: any SystemCatalogSyncing
    private let selectedProgramReconciler: SelectedProgramReconciliationService

    // The composition root keeps the complete dependency graph visible in one place.
    // swiftlint:disable:next function_body_length
    init(
        repositoryFactory: some RepositoryFactory,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        profileBootstrapper: any ProfileBootstrapping
    ) {
        let dataChangeDispatcher = AppDataChangeDispatcher()
        let programDetailService = ProgramDetailService(
            userRepository: repositoryFactory.userRepository,
            defaultProgramCatalogRepository: repositoryFactory.defaultProgramCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let miniPlayerService = MiniPlayerService(
            userRepository: repositoryFactory.userRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )
        let miniPlayerViewModel = MiniPlayerViewModel(
            service: miniPlayerService,
            workoutRepository: repositoryFactory.workoutRepository,
            onDataChanged: dataChangeDispatcher.send
        )
        let programDetailViewModel = ProgramDetailViewModel(
            userRepository: repositoryFactory.userRepository,
            service: programDetailService,
            onDataChanged: dataChangeDispatcher.send
        )
        let catalogViewModel = CatalogViewModel(
            userRepository: repositoryFactory.userRepository,
            defaultProgramCatalogRepository: repositoryFactory.defaultProgramCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository,
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
            reloadMiniPlayer: { [weak miniPlayerViewModel] in
                await miniPlayerViewModel?.reload()
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
        self.miniPlayerViewModel = miniPlayerViewModel
        self.programDetailViewModel = programDetailViewModel
        self.dataChangeCoordinator = dataChangeCoordinator
        self.dataChangeDispatcher = dataChangeDispatcher
        self.userRepository = repositoryFactory.userRepository
        self.profileBootstrapper = profileBootstrapper
        self.syncCoordinator = syncCoordinator
        self.systemCatalogSynchronizer = systemCatalogSynchronizer
        selectedProgramReconciler = SelectedProgramReconciliationService(
            userRepository: repositoryFactory.userRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository
        )

        dataChangeDispatcher.install(handler: dataChangeCoordinator.handle)
    }

    /// Refreshes the local catalog and routes actual source-of-truth changes through the dispatcher.
    func refreshSystemCatalog() async -> Bool {
        do {
            let didChange = try await systemCatalogSynchronizer.refreshSystemCatalog()
            guard didChange else { return false }
            await dataChangeDispatcher.send(.programCatalog)
            return true
        } catch {
            // Cached or bundled SwiftData content remains usable while offline.
            return false
        }
    }

    /// Runs one ordered foreground refresh and reports whether local source-of-truth data changed.
    func refreshAfterBecomingActive(for userID: UUID) async -> Bool {
        let selectedProgramBefore = try? await userRepository
            .user(id: userID)?.selectedProgramId
        let catalogDidChange = await refreshSystemCatalogWithoutDispatch()
        let selectionWasReconciled = (
            try? await selectedProgramReconciler.clearUnavailableSelection(
                for: userID
            )
        ) ?? false

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

        return catalogDidChange || selectionWasReconciled || profileDidChange
    }

    private func refreshSystemCatalogWithoutDispatch() async -> Bool {
        do {
            return try await systemCatalogSynchronizer.refreshSystemCatalog()
        } catch {
            return false
        }
    }
}
