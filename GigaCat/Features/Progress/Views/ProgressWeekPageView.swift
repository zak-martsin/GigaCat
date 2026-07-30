import SwiftUI

struct ProgressWeekPageView: View {
    let viewData: ProgressWeekViewData
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    // MARK: - Layout

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewData.days) { day in
                ProgressWeekDayView(
                    viewData: day,
                    isSelected: day.date == selectedDate
                ) {
                    onSelectDate(day.date)
                }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ProgressWeekDayView: View {
    let viewData: ProgressWeekDayViewData
    let isSelected: Bool
    let onSelect: () -> Void

    // MARK: - Layout

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppSpacing.sm) {
                Text(viewData.dayNumberText)
                    .font(.subheadline.weight(viewData.hasWorkout ? .bold : .medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(
                        width: AppControlSize.iconButton,
                        height: AppControlSize.iconButton
                    )
                    .overlay {
                        if viewData.hasWorkout {
                            Circle()
                                .strokeBorder(AppColor.accent, lineWidth: 2)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if viewData.isToday {
                            Circle()
                                .fill(AppColor.accent)
                                .frame(
                                    width: AppControlSize.statusIndicator,
                                    height: AppControlSize.statusIndicator
                                )
                        }
                    }

                Text(viewData.weekdayText)
                    .font(.caption2.weight(viewData.isToday ? .bold : .medium))
                    .foregroundStyle(
                        viewData.isToday
                            ? AppColor.textPrimary
                            : AppColor.textSecondary
                    )
                    .lineLimit(1)

                Capsule()
                    .fill(isSelected ? AppColor.accent : Color.clear)
                    .frame(height: 2)
                    .shadow(
                        color: isSelected
                            ? AppColor.accent.opacity(0.35)
                            : Color.clear,
                        radius: AppSpacing.xs,
                        y: AppSpacing.xs
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(viewData.weekdayText), \(viewData.dayNumberText)"
        )
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityValue: String {
        switch (viewData.isToday, viewData.hasWorkout) {
        case (true, true):
            "Today, workout completed"
        case (true, false):
            "Today"
        case (false, true):
            "Workout completed"
        case (false, false):
            ""
        }
    }
}
