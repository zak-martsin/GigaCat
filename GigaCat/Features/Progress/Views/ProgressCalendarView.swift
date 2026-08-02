import SwiftUI

struct ProgressCalendarView: View {
    let viewModel: ProgressCalendarViewModel

    // MARK: - Layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                ProgressMonthPagerView(
                    pages: viewModel.monthPages,
                    selectedMonthStart: selectedMonthBinding,
                    onSelectDate: viewModel.selectDate
                )

                ProgressDayHistoryView(
                    selectedDate: viewModel.selectedDate,
                    sessions: viewModel.selectedDaySessions
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Bindings

    private var selectedMonthBinding: Binding<Date?> {
        Binding(
            get: { viewModel.displayedMonthStart },
            set: { selectedMonthStart in
                guard let selectedMonthStart else { return }
                viewModel.showMonth(startingAt: selectedMonthStart)
            }
        )
    }
}
