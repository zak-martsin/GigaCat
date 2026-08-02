import SwiftUI

struct ProgressMonthPagerView: View {
    let pages: [ProgressMonthViewData]
    @Binding var selectedMonthStart: Date?
    let onSelectDate: (Date) -> Void

    // MARK: - Layout

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            monthTitle
            weekdayRow
            monthPager
        }
    }

    private var monthTitle: some View {
        Text(selectedPage?.title ?? "")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(AppColor.textPrimary)
            .contentTransition(.opacity)
            .animation(.easeInOut, value: selectedPage?.title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(
                Array((selectedPage?.weekdayTitles ?? []).enumerated()),
                id: \.offset
            ) { _, title in
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { page in
                    ProgressMonthPageView(
                        viewData: page,
                        onSelectDate: onSelectDate
                    )
                        .containerRelativeFrame(.horizontal)
                        .id(page.startDate)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedMonthStart)
    }

    private var selectedPage: ProgressMonthViewData? {
        guard let selectedMonthStart else {
            return pages.last
        }

        return pages.first { page in
            page.startDate == selectedMonthStart
        }
    }
}
