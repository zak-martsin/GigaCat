import SwiftUI

struct WorkoutContentView: View {
    let viewData: WorkoutViewData
    let onSelectDay: (UUID) -> Void
    let onProgramInfo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                programCard
                daySelector
                exerciseSection
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var programCard: some View {
        HStack(spacing: AppSpacing.md) {
            Text(viewData.programTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onProgramInfo) {
                Image(systemName: "info")
                    .font(.system(size: AppIconSize.programInfo, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(
                        width: AppControlSize.programInfoButton,
                        height: AppControlSize.programInfoButton
                    )
                    .background(AppColor.background, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AppColor.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Program information")
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColor.border, lineWidth: 1)
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewData.days) { day in
                    WorkoutDayChip(day: day) {
                        onSelectDay(day.id)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Exercises")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            if viewData.selectedDay.exercises.isEmpty {
                AppMessageCard(
                    title: "No exercises planned",
                    message: "This workout day does not contain any exercises yet."
                )
            } else {
                ForEach(viewData.selectedDay.exercises) { exercise in
                    WorkoutExerciseRow(exercise: exercise)
                }
            }
        }
    }
}

private struct WorkoutDayChip: View {
    let day: WorkoutDayItemViewData
    let action: () -> Void

    var body: some View {
        AppChipView(
            title: day.title,
            isSelected: day.isSelected,
            action: action
        )
        .overlay(alignment: .topTrailing) {
            if day.hasActiveSession {
                Circle()
                    .fill(AppColor.success)
                    .frame(
                        width: AppControlSize.statusIndicator,
                        height: AppControlSize.statusIndicator
                    )
                    .overlay {
                        Circle()
                            .stroke(AppColor.surface, lineWidth: 2)
                    }
            }
        }
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch (day.isSelected, day.hasActiveSession) {
        case (true, true):
            "Selected, active workout"
        case (true, false):
            "Selected"
        case (false, true):
            "Active workout"
        case (false, false):
            ""
        }
    }
}

private struct WorkoutExerciseRow: View {
    let exercise: WorkoutExerciseViewData

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColor.background)
                .frame(
                    width: AppControlSize.exerciseArtwork,
                    height: AppControlSize.exerciseArtwork
                )
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: AppIconSize.exerciseArtwork, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)

                Text("\(exercise.targetSets) x \(exercise.targetReps) reps")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColor.border, lineWidth: 1)
        }
    }
}
