import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: AppTab = .home
    @State private var isProfilePresented = false
    @State private var workoutViewModel: WorkoutViewModel
    @StateObject private var homeViewModel: HomeViewModel

    init(repositoryFactory: MockRepositoryFactory = MockRepositoryFactory()) {
        let workoutContextService = WorkoutContextService(
            userRepository: repositoryFactory.userRepository,
            programCatalogRepository: repositoryFactory.programCatalogRepository,
            workoutProgramRepository: repositoryFactory.workoutProgramRepository,
            workoutRepository: repositoryFactory.workoutRepository
        )

        _workoutViewModel = State(
            initialValue: WorkoutViewModel(contextService: workoutContextService)
        )
        _homeViewModel = StateObject(
            wrappedValue: HomeViewModel(
                userRepository: repositoryFactory.userRepository,
                programCatalogRepository: repositoryFactory.programCatalogRepository,
                workoutProgramRepository: repositoryFactory.workoutProgramRepository,
                workoutRepository: repositoryFactory.workoutRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
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

                ProgressView(onHeaderAction: handleHeaderAction)
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

                LibraryView(onHeaderAction: handleHeaderAction)
                    .tag(AppTab.library)
                    .tabItem {
                        Label(AppTab.library.title, systemImage: AppTab.library.systemImage)
                    }
            }
            .tabViewBottomAccessory(isEnabled: true) {
                ProgramMiniPlayerView(
                    state: homeViewModel.miniPlayerState,
                    onTap: openMiniPlayerProgramDetail,
                    onPrimaryAction: handleMiniPlayerAction
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(AppColor.background.ignoresSafeArea())
        }
        .alert(
            homeViewModel.expiredSessionAlert?.title ?? "",
            isPresented: expiredSessionAlertIsPresented,
            presenting: homeViewModel.expiredSessionAlert
        ) { _ in
            Button("Continue") {
                Task {
                    let route = await homeViewModel.continueExpiredSession()
                    if route == .openWorkout {
                        openWorkoutTab()
                    }
                }
            }

            Button("Finish") {
                Task {
                    await homeViewModel.completeExpiredSession()
                }
            }

            Button("Discard", role: .destructive) {
                Task {
                    await homeViewModel.deleteExpiredSession()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileSheetView(user: homeViewModel.profileUser)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await homeViewModel.loadIfNeeded()
        }
    }

    private func openWorkoutTab() {
        selectedTab = .workout
    }

    private func handleMiniPlayerAction() {
        Task {
            let route = await homeViewModel.handleMiniPlayerAction()
            if route == .openWorkout {
                openWorkoutTab()
            }
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
        Task {
            await homeViewModel.presentSelectedProgramDetail()
        }
    }

    private var expiredSessionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { homeViewModel.expiredSessionAlert != nil },
            set: { isPresented in
                if !isPresented {
                    homeViewModel.expiredSessionAlert = nil
                }
            }
        )
    }
}

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
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColor.border, lineWidth: 1)
                        }
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
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColor.border, lineWidth: 1)
        }
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
