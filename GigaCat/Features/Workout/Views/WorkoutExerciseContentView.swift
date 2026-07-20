import SwiftUI

struct WorkoutExerciseContentView: View {
    let viewData: WorkoutExerciseDetailViewData
    let onPreviousExercise: () -> Void
    let onNextExercise: () -> Void

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
                WorkoutSetTargetRow(viewData: set)
            }
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

private struct WorkoutSetTargetRow: View {
    let viewData: WorkoutSetTargetViewData

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text("Set \(viewData.setNumber)")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Text("\(viewData.targetReps) reps")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .monospacedDigit()

            if let targetWeight = viewData.targetWeight {
                Text("\(formattedWeight(targetWeight)) kg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColor.border, lineWidth: 1)
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
}
