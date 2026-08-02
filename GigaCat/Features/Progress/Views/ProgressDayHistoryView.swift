import SwiftUI

struct ProgressDayHistoryView: View {
    let selectedDate: Date?
    let sessions: [ProgressSessionViewData]

    // MARK: - Layout

    @ViewBuilder
    var body: some View {
        if selectedDate == nil {
            emptyMessage("Select a day to view its workout history.")
        } else if sessions.isEmpty {
            emptyMessage("No completed workouts on this day.")
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                ForEach(sessions) { session in
                    ProgressSessionHistoryView(viewData: session)

                    if session.id != sessions.last?.id {
                        Divider()
                            .overlay(AppColor.border)
                    }
                }
            }
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProgressSessionHistoryView: View {
    let viewData: ProgressSessionViewData

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                Text(viewData.title)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(viewData.timeText)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            ForEach(viewData.exercises) { exercise in
                ProgressExerciseHistoryView(viewData: exercise)
            }
        }
    }
}

private struct ProgressExerciseHistoryView: View {
    let viewData: ProgressExerciseViewData

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(viewData.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)

            ForEach(viewData.sets) { set in
                HStack(spacing: AppSpacing.sm) {
                    Text(set.setNumberText)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .monospacedDigit()
                        .frame(minWidth: AppControlSize.iconButton)

                    Divider()
                        .frame(height: AppSpacing.xl)

                    Text(set.weightText)
                        .font(.headline)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: AppSpacing.xl)

                    Text(set.repetitionsText)
                        .font(.headline)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity)
                .frame(height: AppControlSize.fieldHeight)
                .appCardStyle()
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Set \(set.setNumberText), \(set.weightText), \(set.repetitionsText)"
                )
            }
        }
    }
}
