import SwiftUI

struct WorkoutExerciseContentView: View {
    let viewData: WorkoutExerciseDetailViewData
    let onPreviousExercise: () -> Void
    let onNextExercise: () -> Void
    let onAddSet: () -> Void
    let onSaveSet: (Int, String, String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                positionLabel
                artworkNavigation
                exerciseTitle
                targetSetList
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var positionLabel: some View {
        Text("\(viewData.position) of \(viewData.totalCount)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.textSecondary)
            .monospacedDigit()
    }

    private var artworkNavigation: some View {
        HStack(spacing: AppSpacing.lg) {
            navigationButton(
                systemImage: "chevron.left",
                isEnabled: viewData.canGoBack,
                accessibilityLabel: "Previous exercise",
                action: onPreviousExercise
            )

            ProgramArtworkPlaceholderView(
                cornerRadius: AppRadius.lg,
                height: AppControlSize.exerciseDetailArtwork,
                width: AppControlSize.exerciseDetailArtwork
            ) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: AppIconSize.exerciseDetailArtwork, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }

            navigationButton(
                systemImage: "chevron.right",
                isEnabled: viewData.canGoForward,
                accessibilityLabel: "Next exercise",
                action: onNextExercise
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var exerciseTitle: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(viewData.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(viewData.targetSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var targetSetList: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(viewData.sets) { set in
                WorkoutSetRow(
                    viewData: set,
                    onSave: onSaveSet
                )
            }

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppControlSize.fieldHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add set")
        }
    }

    private func navigationButton(
        systemImage: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: AppIconSize.exerciseNavigation, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(
                    width: AppControlSize.exerciseNavigationButton,
                    height: AppControlSize.exerciseNavigationButton
                )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct WorkoutSetRow: View {
    let viewData: WorkoutSetRowViewData
    let onSave: (Int, String, String) -> Void

    @State private var weightText: String
    @State private var repsText: String

    init(
        viewData: WorkoutSetRowViewData,
        onSave: @escaping (Int, String, String) -> Void
    ) {
        self.viewData = viewData
        self.onSave = onSave
        _weightText = State(initialValue: viewData.savedWeightText ?? "")
        _repsText = State(initialValue: viewData.savedRepsText ?? "")
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            setValues
            saveButton
        }
        .frame(height: AppControlSize.fieldHeight)
        .onChange(of: viewData) { oldValue, newValue in
            synchronizeDraftIfNeeded(from: oldValue, to: newValue)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Set \(viewData.setNumber)")
    }

    private var setValues: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("\(viewData.setNumber)")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
                .frame(minWidth: AppControlSize.headerActionButton)

            Divider()
                .frame(height: AppSpacing.xl)

            valueField(
                text: $weightText,
                placeholder: viewData.suggestedWeightPlaceholder ?? "Weight",
                unit: "kg",
                keyboardType: .decimalPad
            )

            valueField(
                text: $repsText,
                placeholder: viewData.suggestedRepsPlaceholder,
                unit: "rep",
                keyboardType: .numberPad
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appCardStyle()
    }

    private var saveButton: some View {
        Button {
            guard canSave else { return }
            onSave(
                viewData.setNumber,
                effectiveWeightText,
                effectiveRepsText
            )
        } label: {
            ZStack {
                if showsSavedState {
                    Image(systemName: "checkmark")
                        .transition(.blurReplace)
                } else {
                    Image(systemName: "plus")
                        .symbolEffect(.rotate, isActive: viewData.isSaving)
                        .transition(.blurReplace)
                }
            }
                .animation(.snappy, value: showsSavedState)
                .frame(
                    width: AppControlSize.headerActionButton,
                    height: AppControlSize.headerActionButton
                )
                .foregroundStyle(AppColor.surface)
                .background(AppColor.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(canSave)
        .accessibilityLabel(showsSavedState ? "Set saved" : "Save set")
    }

    private var showsSavedState: Bool {
        viewData.isSaved && !isDirty && !viewData.isSaving
    }

    private var isDirty: Bool {
        weightText != (viewData.savedWeightText ?? "") ||
            repsText != (viewData.savedRepsText ?? "")
    }

    private var canSave: Bool {
        !viewData.isSaving &&
            !effectiveWeightText.isEmpty &&
            !effectiveRepsText.isEmpty &&
            (!viewData.isSaved || isDirty)
    }

    private var effectiveWeightText: String {
        let enteredWeight = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        return enteredWeight.isEmpty
            ? viewData.suggestedWeightPlaceholder ?? ""
            : enteredWeight
    }

    private var effectiveRepsText: String {
        let enteredReps = repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        return enteredReps.isEmpty
            ? viewData.suggestedRepsPlaceholder
            : enteredReps
    }

    private func synchronizeDraftIfNeeded(
        from oldValue: WorkoutSetRowViewData,
        to newValue: WorkoutSetRowViewData
    ) {
        let didLoadSavedLog = !oldValue.isSaved && newValue.isSaved
        let didFinishSaving = oldValue.isSaving && !newValue.isSaving && newValue.isSaved

        if didLoadSavedLog || didFinishSaving {
            weightText = newValue.savedWeightText ?? ""
            repsText = newValue.savedRepsText ?? ""
        }
    }

    private func valueField(
        text: Binding<String>,
        placeholder: String,
        unit: String,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: AppSpacing.xs) {
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .font(.headline)
                .monospacedDigit()

            Text(unit)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
