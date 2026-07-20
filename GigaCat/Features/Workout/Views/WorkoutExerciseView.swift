import SwiftUI

struct WorkoutExerciseView: View {
    @State private var viewModel: WorkoutExerciseViewModel
    @State private var transitionDirection: ExerciseTransitionDirection = .forward

    private let mapper = WorkoutExerciseDetailViewDataMapper()
    private let onExerciseInfo: () -> Void

    init(
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID,
        onExerciseInfo: @escaping () -> Void = {}
    ) {
        _viewModel = State(
            initialValue: WorkoutExerciseViewModel(
                dayContent: dayContent,
                initialDayExerciseID: initialDayExerciseID
            )
        )
        self.onExerciseInfo = onExerciseInfo
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let viewData {
                WorkoutExerciseContentView(
                    viewData: viewData,
                    onPreviousExercise: selectPreviousExercise,
                    onNextExercise: selectNextExercise
                )
                .id(viewData.id)
                .transition(contentTransition)
            } else {
                AppMessageCard(
                    title: "Exercise unavailable",
                    message: "This workout day does not contain an exercise to display."
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onExerciseInfo) {
                    Image(systemName: "info")
                }
                .accessibilityLabel("Exercise information")
            }
        }
    }

    private var viewData: WorkoutExerciseDetailViewData? {
        guard let selectedExercise = viewModel.selectedExercise,
              let selectedExerciseIndex = viewModel.selectedExerciseIndex else {
            return nil
        }

        return mapper.map(
            selectedExercise: selectedExercise,
            selectedExerciseIndex: selectedExerciseIndex,
            totalCount: viewModel.exercises.count,
            canGoBack: viewModel.canSelectPreviousExercise,
            canGoForward: viewModel.canSelectNextExercise
        )
    }

    private var contentTransition: AnyTransition {
        switch transitionDirection {
        case .forward:
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func selectPreviousExercise() {
        transitionDirection = .backward
        withAnimation(.snappy(duration: 0.3)) {
            viewModel.selectPreviousExercise()
        }
    }

    private func selectNextExercise() {
        transitionDirection = .forward
        withAnimation(.snappy(duration: 0.3)) {
            viewModel.selectNextExercise()
        }
    }
}

private enum ExerciseTransitionDirection {
    case forward
    case backward
}
