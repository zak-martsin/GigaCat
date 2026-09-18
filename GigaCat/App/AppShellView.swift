import SwiftUI

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let container: AppContainer
    private let userID: UUID
    private let onSignOut: () -> Void
    @State private var selectedTab: AppTab = .catalog
    @State private var isProfilePresented = false
    @State private var isUnavailableNoticeVisible = false
    @State private var isSyncFailureNoticeVisible = false
    @State private var workoutViewModel: WorkoutViewModel
    @State private var progressViewModel: ProgressViewModel
    @StateObject private var catalogViewModel: CatalogViewModel
    @StateObject private var miniPlayerViewModel: MiniPlayerViewModel
    @StateObject private var programDetailViewModel: ProgramDetailViewModel
    @StateObject private var profileSheetViewModel: ProfileSheetViewModel

    // MARK: - Initialization

    init(
        repositoryFactory: some RepositoryFactory,
        userID: UUID,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        profileBootstrapper: any ProfileBootstrapping,
        profileSyncRecoveryService: any ProfileSyncRecovering,
        onSignOut: @escaping () -> Void = {}
    ) {
        let container = AppContainer(
            repositoryFactory: repositoryFactory,
            syncCoordinator: syncCoordinator,
            systemCatalogSynchronizer: systemCatalogSynchronizer,
            profileBootstrapper: profileBootstrapper
        )

        self.container = container
        self.userID = userID
        self.onSignOut = onSignOut
        _workoutViewModel = State(initialValue: container.workoutViewModel)
        _progressViewModel = State(initialValue: container.progressViewModel)
        _catalogViewModel = StateObject(wrappedValue: container.catalogViewModel)
        _miniPlayerViewModel = StateObject(wrappedValue: container.miniPlayerViewModel)
        _programDetailViewModel = StateObject(wrappedValue: container.programDetailViewModel)
        _profileSheetViewModel = StateObject(
            wrappedValue: ProfileSheetViewModel(
                recoveryService: profileSyncRecoveryService,
                userID: userID
            )
        )
    }

    // MARK: - Layout

    var body: some View {

        TabView(selection: $selectedTab) {
            CatalogView(
                viewModel: catalogViewModel,
                onOpenWorkout: openWorkoutTab,
                onOpenProfile: { isProfilePresented = true }
            )
            .tag(AppTab.catalog)
            .tabItem {
                Label(AppTab.catalog.title, systemImage: AppTab.catalog.systemImage)
            }

            WorkoutView(
                viewModel: workoutViewModel,
                isActive: selectedTab == .workout,
                onHeaderAction: handleHeaderAction,
                onOpenCatalog: openCatalogTab,
                onProgramInfo: openProgramDetail
            )
            .tag(AppTab.workout)
            .tabItem {
                Label(AppTab.workout.title, systemImage: AppTab.workout.systemImage)
            }

            ProgressView(
                viewModel: progressViewModel,
                onHeaderAction: handleHeaderAction
            )
            .tag(AppTab.progress)
            .tabItem {
                Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage)
            }
        }
        .tabViewBottomAccessory(isEnabled: selectedTab != .workout) {
            ProgramMiniPlayerView(
                state: miniPlayerViewModel.state,
                onTap: openMiniPlayerProgramDetail,
                onPrimaryAction: handleMiniPlayerAction
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(AppColor.background.ignoresSafeArea())

        .alert(
            miniPlayerViewModel.expiredSessionAlert?.title ?? "",
            isPresented: expiredSessionAlertIsPresented,
            presenting: miniPlayerViewModel.expiredSessionAlert
        ) { _ in
            Button("Continue") {
                Task {
                    let route = miniPlayerViewModel.continueExpiredSession()
                    if route == .openWorkout {
                        openWorkoutTab()
                    }
                }
            }

            Button("Finish") {
                Task {
                    await miniPlayerViewModel.completeExpiredSession()
                    await loadSelectedTabIfNeeded()
                }
            }

            Button("Discard", role: .destructive) {
                Task {
                    await miniPlayerViewModel.deleteExpiredSession()
                    await loadSelectedTabIfNeeded()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .sheet(item: $programDetailViewModel.presentedDetail) { detail in
            appProgramDetailSheet(detail)
        }
        .overlay {
            programSelectionConflictOverlay
        }
        .overlay(alignment: .top) {
            VStack(spacing: AppSpacing.sm) {
                if isUnavailableNoticeVisible {
                    foregroundNotice(
                        "Selected program is no longer available.",
                        identifier: "selectedProgramUnavailableNotice"
                    )
                }
                if isSyncFailureNoticeVisible {
                    foregroundNotice(
                        "Your program change could not sync. It is still saved on this device.",
                        identifier: "profileSyncFailureNotice"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .allowsHitTesting(false)
        }
        .alert(
            "Program unavailable",
            isPresented: programDetailErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(programDetailViewModel.errorMessage ?? "Please try again.")
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileSheetView(
                user: catalogViewModel.profileUser,
                viewModel: profileSheetViewModel,
                onSignOut: signOut
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: selectedTab) {
            switch selectedTab {
            case .catalog:
                await catalogViewModel.loadIfNeeded()
            case .workout:
                await workoutViewModel.loadIfNeeded()
            case .progress:
                await progressViewModel.loadIfNeeded()
            }
        }
        .task {
            await miniPlayerViewModel.reload()
        }
        .task {
            await refreshAfterBecomingActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshAfterBecomingActive()
            }
        }
        .task(id: isUnavailableNoticeVisible) {
            guard isUnavailableNoticeVisible else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            isUnavailableNoticeVisible = false
        }
        .task(id: isSyncFailureNoticeVisible) {
            guard isSyncFailureNoticeVisible else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            isSyncFailureNoticeVisible = false
        }
    }

}

private extension AppShellView {
    // MARK: - Navigation and Actions

    private func refreshAfterBecomingActive() async {
        let result = await container.refreshAfterBecomingActive(for: userID)
        if result.didChange {
            await loadSelectedTabIfNeeded()
        }
        if result.selectedProgramBecameUnavailable {
            isUnavailableNoticeVisible = true
        }
        if profileSheetViewModel.refreshSyncStatus() {
            isSyncFailureNoticeVisible = true
        }
    }

    private func foregroundNotice(_ message: String, identifier: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(AppColor.textPrimary)
            .padding(AppSpacing.md)
            .appCardStyle()
            .accessibilityIdentifier(identifier)
    }

    private func openWorkoutTab() {
        selectedTab = .workout
    }

    private func openCatalogTab() {
        selectedTab = .catalog
    }

    private func loadSelectedTabIfNeeded() async {
        switch selectedTab {
        case .catalog:
            await catalogViewModel.loadIfNeeded()
        case .workout:
            await workoutViewModel.loadIfNeeded()
        case .progress:
            await progressViewModel.loadIfNeeded()
        }
    }

    private func handleMiniPlayerAction() {
        let route = miniPlayerViewModel.handlePrimaryAction()
        if route == .openWorkout {
            openWorkoutTab()
        }
    }

    private func handleHeaderAction(_ action: HeaderAction) {
        switch action {
        case .profile:
            isProfilePresented = true
        }
    }

    private func signOut() {
        isProfilePresented = false
        onSignOut()
    }

    private func openMiniPlayerProgramDetail() {
        guard let programID = miniPlayerViewModel.programID else { return }

        openProgramDetail(programID)
    }

    private func openProgramDetail(_ programID: UUID) {
        Task {
            await programDetailViewModel.present(programID: programID)
        }
    }

    private func appProgramDetailSheet(_ detail: ProgramDetail) -> some View {
        ProgramDetailSheet(
            detail: detail,
            onSelectProgram: {
                Task {
                    await programDetailViewModel.selectPresentedProgram()
                    await loadSelectedTabIfNeeded()
                }
            },
            onCompleteSession: {
                Task {
                    await programDetailViewModel.completeActiveSession()
                    await loadSelectedTabIfNeeded()
                }
            },
            onDeleteSession: {
                Task {
                    await programDetailViewModel.cancelActiveSession()
                    await loadSelectedTabIfNeeded()
                }
            },
            onOpenWorkout: {
                programDetailViewModel.dismiss()
                openWorkoutTab()
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var programSelectionConflictOverlay: some View {
        if let alert = programDetailViewModel.selectionConflictAlert {
            SessionConflictDialog(
                alert: alert,
                onFinishSession: {
                    Task {
                        await programDetailViewModel.finishSessionAndSelectPendingProgram()
                        await loadSelectedTabIfNeeded()
                    }
                },
                onCancelSession: {
                    Task {
                        await programDetailViewModel.cancelSessionAndSelectPendingProgram()
                        await loadSelectedTabIfNeeded()
                    }
                },
                onDismiss: programDetailViewModel.cancelSelectionConflict
            )
        }
    }

    // MARK: - Bindings

    private var expiredSessionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { miniPlayerViewModel.expiredSessionAlert != nil },
            set: { isPresented in
                if !isPresented {
                    miniPlayerViewModel.expiredSessionAlert = nil
                }
            }
        )
    }

    private var programDetailErrorIsPresented: Binding<Bool> {
        Binding(
            get: { programDetailViewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    programDetailViewModel.errorMessage = nil
                }
            }
        )
    }
}

// MARK: - Supporting Views

private struct ProgramMiniPlayerView: View {
    let state: MiniPlayerState
    let onTap: () -> Void
    let onPrimaryAction: () -> Void

    // MARK: - Layout

    var body: some View {
        GlassEffectContainer(spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.accent.opacity(0.95), AppColor.textSecondary.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: AppControlSize.miniPlayerArtwork,
                        height: AppControlSize.miniPlayerArtwork
                    )
                    .overlay {
                        ZStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: AppIconSize.miniPlayerArtwork, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .offset(y: 4)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)

                    Text(state.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: AppSpacing.md)

                if state.action != .none {
                    actionButton
                        .offset(y: 4)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var actionButton: some View {
        let button = Button(action: onPrimaryAction) {
            Text(state.action == .continueWorkout ? "Continue" : "Start")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.lg)
        }
            .frame(height: AppControlSize.fieldHeight)
            .buttonStyle(.glassProminent)

        if state.action == .start {
            button.tint(.green)
        } else {
            button
        }
    }
}
