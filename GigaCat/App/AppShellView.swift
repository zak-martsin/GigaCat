import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: AppTab = .home
    @State private var isProfilePresented = false
    @State private var workoutViewModel: WorkoutViewModel
    @State private var libraryViewModel: LibraryViewModel
    @State private var progressViewModel: ProgressViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var miniPlayerViewModel: MiniPlayerViewModel
    @StateObject private var programDetailViewModel: ProgramDetailViewModel

    // MARK: - Initialization

    init(repositoryFactory: MockRepositoryFactory = MockRepositoryFactory()) {
        let container = AppContainer(repositoryFactory: repositoryFactory)

        _workoutViewModel = State(initialValue: container.workoutViewModel)
        _libraryViewModel = State(initialValue: container.libraryViewModel)
        _progressViewModel = State(initialValue: container.progressViewModel)
        _homeViewModel = StateObject(wrappedValue: container.homeViewModel)
        _miniPlayerViewModel = StateObject(wrappedValue: container.miniPlayerViewModel)
        _programDetailViewModel = StateObject(wrappedValue: container.programDetailViewModel)
    }

    // MARK: - Layout

    var body: some View {

        TabView(selection: $selectedTab) {
            HomeView(
                viewModel: homeViewModel,
                onOpenWorkout: openWorkoutTab,
                onHeaderAction: handleHeaderAction
            )
            .tag(AppTab.home)
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }

            ProgressView(
                viewModel: progressViewModel,
                onHeaderAction: handleHeaderAction
            )
                .tag(AppTab.progress)
                .tabItem {
                    Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage)
                }

            WorkoutView(
                viewModel: workoutViewModel,
                onHeaderAction: handleHeaderAction
            )
            .tag(AppTab.workout)
            .tabItem {
                Label(AppTab.workout.title, systemImage: AppTab.workout.systemImage)
            }

            NutritionView(onHeaderAction: handleHeaderAction)
                .tag(AppTab.nutrition)
                .tabItem {
                    Label(AppTab.nutrition.title, systemImage: AppTab.nutrition.systemImage)
                }

            LibraryView(
                viewModel: libraryViewModel,
                onOpenWorkout: openWorkoutTab,
                onHeaderAction: handleHeaderAction
            )
                .tag(AppTab.library)
                .tabItem {
                    Label(AppTab.library.title, systemImage: AppTab.library.systemImage)
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
                }
            }

            Button("Discard", role: .destructive) {
                Task {
                    await miniPlayerViewModel.deleteExpiredSession()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .sheet(item: presentedProgramDetail) { detail in
            appProgramDetailSheet(detail)
        }
        .overlay {
            programSelectionConflictOverlay
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
            ProfileSheetView(user: homeViewModel.profileUser)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: selectedTab) {
            switch selectedTab {
            case .home:
                await homeViewModel.loadIfNeeded()
            case .workout:
                await workoutViewModel.loadIfNeeded()
            case .progress:
                await progressViewModel.loadIfNeeded()
            case .library:
                await libraryViewModel.loadIfNeeded()
            case .nutrition:
                break
            }
        }
        .task {
            await miniPlayerViewModel.reload()
        }
    }

    // MARK: - Navigation and Actions

    private func openWorkoutTab() {
        selectedTab = .workout
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
        case .search, .add, .more:
            break
        }
    }

    private func openMiniPlayerProgramDetail() {
        guard let programID = miniPlayerViewModel.programID else { return }

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
                }
            },
            onAddToLibrary: {
                Task {
                    await programDetailViewModel.addPresentedProgramToLibrary()
                }
            },
            onRemoveFromLibrary: {
                Task {
                    await programDetailViewModel.removePresentedProgramFromLibrary()
                }
            },
            onCompleteSession: {
                Task {
                    await programDetailViewModel.completeActiveSession()
                }
            },
            onDeleteSession: {
                Task {
                    await programDetailViewModel.cancelActiveSession()
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
                    }
                },
                onCancelSession: {
                    Task {
                        await programDetailViewModel.cancelSessionAndSelectPendingProgram()
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

    private var presentedProgramDetail: Binding<ProgramDetail?> {
        Binding(
            get: { programDetailViewModel.presentedDetail },
            set: { programDetailViewModel.presentedDetail = $0 }
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

private struct ProfileSheetView: View {
    let user: User?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Profile")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if let user {
                    profileRow(title: "Apple User ID", value: user.appleUserId)
                    profileRow(title: "User ID", value: user.id.uuidString)
                    profileRow(
                        title: "Selected Program ID",
                        value: user.selectedProgramId?.uuidString ?? "No program selected"
                    )
                    profileRow(title: "Created At", value: formatted(user.createdAt))
                    profileRow(title: "Updated At", value: formatted(user.updatedAt))
                } else {
                    Text("User profile is not available yet.")
                        .font(.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                        .appCardStyle()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            Text(value)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .appCardStyle()
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

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
