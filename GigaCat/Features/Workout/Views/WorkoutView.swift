import SwiftUI

struct WorkoutView: View {
    @State private var selectedDayExerciseID: UUID?

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
