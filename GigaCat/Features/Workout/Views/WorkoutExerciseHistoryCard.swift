import SwiftUI

struct WorkoutExerciseHistoryCard: View {
    let previousResult: WorkoutExerciseResultViewData
    let bestResult: WorkoutExerciseResultViewData

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            resultColumn(
                title: "Previous",
                result: previousResult
            )

            Rectangle()
                .fill(AppColor.border)
                .frame(width: 1)
                .padding(.vertical, AppSpacing.xs)
                .accessibilityHidden(true)

            resultColumn(
                title: "Best",
                result: bestResult
            )
        }
        .padding(AppSpacing.lg)
        .appCardStyle(.subtle)
    }

    private func resultColumn(
        title: String,
        result: WorkoutExerciseResultViewData
    ) -> some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            Text("\(result.weightText) kg × \(result.repsText)")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(result.weightText) kilograms, \(result.repsText) repetitions"
        )
    }
}
