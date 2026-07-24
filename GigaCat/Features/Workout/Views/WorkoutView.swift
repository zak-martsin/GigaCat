import SwiftUI

struct WorkoutView: View {
    @State private var selectedDayExerciseID: UUID?
    @State private var showsFinishConfirmation = false
    @State private var showsCancelConfirmation = false

    let viewModel: WorkoutViewModel
    let onHeaderAction: (HeaderAction) -> Void
    private let mapper = WorkoutViewDataMapper()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView(
                    title: "Workout",
                    actions: [.profile],
                    onAction: onHeaderAction
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                content
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationDestination(item: $selectedDayExerciseID) { dayExerciseID in
                exerciseDestination(for: dayExerciseID)
            }
            .confirmationDialog(
                "Finish workout?",
                isPresented: $showsFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish Workout") {
                    Task {
                        await viewModel.finishActiveSession()
                    }
                }

                Button("Keep Workout", role: .cancel) {}
            } message: {
                Text("Your logged sets will be saved to workout history.")
            }
            .confirmationDialog(
                "Cancel workout?",
                isPresented: $showsCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Workout", role: .destructive) {
                    Task {
                        await viewModel.cancelActiveSession()
                    }
                }

                Button("Keep Workout", role: .cancel) {}
            } message: {
                Text("All logged sets from this workout will be deleted.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            loadingState
        case .loaded:
            loadedState
        case .failed:
            errorState
        }
    }

    @ViewBuilder
    private var loadedState: some View {
        if let context = viewModel.context,
           let selectedDayID = viewModel.selectedDayID,
           let viewData = mapper.map(context: context, selectedDayID: selectedDayID) {
            WorkoutContentView(
                viewData: viewData,
                onSelectDay: viewModel.selectDay,
                onSelectExercise: { selectedDayExerciseID = $0 },
                onProgramInfo: {}
            )
            .safeAreaInset(edge: .bottom) {
                if viewModel.hasActiveSessionForSelectedDay {
                    WorkoutSessionActionBar(
                        state: viewModel.sessionActionState,
                        onFinish: { showsFinishConfirmation = true },
                        onCancel: { showsCancelConfirmation = true }
                    )
                }
            }
        } else {
            errorState
        }
    }

    private var loadingState: some View {
        ScrollView {
            AppMessageCard(
                title: "Loading workout",
                message: "Preparing your program and training days."
            ) {
                SwiftUI.ProgressView()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
    }

    private var errorState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                AppMessageCard(
                    title: "Workout unavailable",
                    message: "We could not prepare this workout. Try loading it again."
                )

                Button("Retry") {
                    Task {
                        await viewModel.load()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppControlSize.buttonHeight)
                .buttonStyle(.glassProminent)
                .tint(AppColor.accent)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
    }

    @ViewBuilder
    private func exerciseDestination(for dayExerciseID: UUID) -> some View {
        if let dayContent = viewModel.selectedDayContent,
           let exerciseViewModel = viewModel.makeExerciseViewModel(
               dayContent: dayContent,
               initialDayExerciseID: dayExerciseID
           ) {
            WorkoutExerciseView(viewModel: exerciseViewModel)
        } else {
            AppMessageCard(
                title: "Exercise unavailable",
                message: "This exercise is no longer part of the selected workout day."
            )
            .padding(AppSpacing.lg)
            .background(AppColor.background.ignoresSafeArea())
        }
    }
}

private struct WorkoutSessionActionBar: View {
    let state: WorkoutSessionActionState
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Menu {
                Button(role: .destructive, action: onCancel) {
                    Label("Cancel Workout", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .rotationEffect(.degrees(90))
                    .frame(
                        width: AppControlSize.buttonHeight,
                        height: AppControlSize.buttonHeight
                    )
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button(action: onFinish) {
                HStack(spacing: AppSpacing.sm) {
                    if state != .idle {
                        SwiftUI.ProgressView()
                            .controlSize(.small)
                    }

                    Text(actionTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppControlSize.buttonHeight)
            }
            .buttonStyle(.glassProminent)
            .tint(AppColor.accent)
        }
        .disabled(state != .idle)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    private var actionTitle: String {
        switch state {
        case .idle:
            "Finish Workout"
        case .finishing:
            "Finishing..."
        case .cancelling:
            "Cancelling..."
        }
    }
}
