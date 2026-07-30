import SwiftUI

struct ProgressWeekPagerView: View {
    let pages: [ProgressWeekViewData]
    @Binding var selectedWeekStart: Date?
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    // MARK: - Layout

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            weekHeader

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        ProgressWeekPageView(
                            viewData: page,
                            selectedDate: selectedDate,
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
            .scrollPosition(id: $selectedWeekStart)
        }
    }

    private var weekHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Text(selectedPage?.monthTitle ?? "")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: selectedPage?.monthTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("See more")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var selectedPage: ProgressWeekViewData? {
        guard let selectedWeekStart else {
            return pages.last
        }

        return pages.first { page in
            page.startDate == selectedWeekStart
        }
    }
}
