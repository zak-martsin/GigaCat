import SwiftUI

struct ProgressView: View {
    let viewModel: ProgressViewModel
    let onHeaderAction: (HeaderAction) -> Void

    // MARK: - Layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

            content
        }
        .background(AppColor.background.ignoresSafeArea())
        .task {
            await viewModel.loadIfNeeded()
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
                        onSelectDate: viewModel.selectDate
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
}
