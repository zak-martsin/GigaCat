import SwiftUI

struct ProgressMonthPageView: View {
    let viewData: ProgressMonthViewData
    let onSelectDate: (Date) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0),
        count: CalendarGridLayout.columnCount
    )

    // MARK: - Layout

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            ForEach(0..<viewData.leadingEmptyDayCount, id: \.self) { _ in
                placeholder
            }

            ForEach(viewData.days) { day in
                ProgressCalendarDayView(viewData: day) {
                    onSelectDate(day.date)
                }
            }

            ForEach(0..<trailingEmptyDayCount, id: \.self) { _ in
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Color.clear
            .frame(
                width: AppControlSize.iconButton,
                height: AppControlSize.iconButton + AppSpacing.sm + 2
            )
    }

    private var trailingEmptyDayCount: Int {
        max(
            0,
            CalendarGridLayout.cellCount
                - viewData.leadingEmptyDayCount
                - viewData.days.count
        )
    }
}

private struct ProgressCalendarDayView: View {
    let viewData: ProgressCalendarDayViewData
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
                    .overlay(alignment: .topTrailing) {
                        if viewData.hasWorkout {
                            Circle()
                                .fill(AppColor.accent)
                                .frame(
                                    width: AppControlSize.statusIndicator,
                                    height: AppControlSize.statusIndicator
                                )
                        }
                    }
                    .overlay {
                        if viewData.isToday {
                            Circle()
                                .strokeBorder(AppColor.accent, lineWidth: 2)
                        }
                    }

                Capsule()
                    .fill(viewData.isSelected ? AppColor.accent : Color.clear)
                    .frame(height: 2)
                    .shadow(
                        color: viewData.isSelected
                            ? AppColor.accent.opacity(0.35)
                            : Color.clear,
                        radius: AppSpacing.xs,
                        y: AppSpacing.xs
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewData.dayNumberText)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(viewData.isSelected ? .isSelected : [])
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

private enum CalendarGridLayout {
    static let columnCount = 7
    static let rowCount = 6
    static let cellCount = columnCount * rowCount
}
