import SwiftUI

struct ProgressView: View {
    @State private var calendarViewModel: ProgressCalendarViewModel?

    let viewModel: ProgressViewModel
    let onHeaderAction: (HeaderAction) -> Void

    // MARK: - Layout

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)

                content
            }
            .background(AppColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: calendarIsPresented) {
                calendarDestination
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        AppHeaderView(
            title: "Progress",
            actions: [.profile],
            onAction: onHeaderAction
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            messageCard(
                title: "Loading progress",
                message: "Preparing your completed workout history."
            ) {
                SwiftUI.ProgressView()
            }
        case .loaded:
            historyContent
        case .empty:
            historyContent(
                message: "Completed workouts will be marked on your calendar."
            )
        case .failed:
            messageCard(
                title: "Progress unavailable",
                message: "Your workout history couldn’t be loaded."
            ) {
                Button("Try Again") {
                    Task {
                        await viewModel.load()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.accent)
            }
        }
    }

    private var historyContent: some View {
        historyContent(message: nil)
    }

    private func historyContent(message: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if !viewModel.weekPages.isEmpty {
                    ProgressWeekPagerView(
                        pages: viewModel.weekPages,
                        selectedWeekStart: selectedWeekBinding,
                        selectedDate: viewModel.selectedDate,
                        onSelectDate: openCalendarForDate,
                        onSeeMore: openCalendar
                    )
                }

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                        .appCardStyle()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private func messageCard<Accessory: View>(
        title: String,
        message: String,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) -> some View {
        AppMessageCard(
            title: title,
            message: message,
            accessory: accessory
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    private var selectedWeekBinding: Binding<Date?> {
        Binding(
            get: { viewModel.displayedWeekStart },
            set: { selectedWeekStart in
                guard let selectedWeekStart else { return }
                viewModel.showWeek(startingAt: selectedWeekStart)
            }
        )
    }

    private var calendarIsPresented: Binding<Bool> {
        Binding(
            get: { calendarViewModel != nil },
            set: { isPresented in
                if !isPresented {
                    calendarViewModel = nil
                }
            }
        )
    }

    // MARK: - Navigation

    @ViewBuilder
    private var calendarDestination: some View {
        if let calendarViewModel {
            ProgressCalendarView(viewModel: calendarViewModel)
        } else {
            AppMessageCard(
                title: "Calendar unavailable",
                message: "Workout history is not loaded yet."
            )
            .padding(AppSpacing.lg)
            .background(AppColor.background.ignoresSafeArea())
        }
    }

    private func openCalendarForDate(_ date: Date) {
        viewModel.selectDate(date)
        openCalendar(selectedDate: date)
    }

    private func openCalendar() {
        openCalendar(selectedDate: nil)
    }

    private func openCalendar(selectedDate: Date?) {
        calendarViewModel = viewModel.makeCalendarViewModel(
            selectedDate: selectedDate
        )
    }
}
