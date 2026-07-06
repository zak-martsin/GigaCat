import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onOpenWorkout: () -> Void
    let onHeaderAction: (HeaderAction) -> Void
    @State private var pendingSearchSelection: ProgramSectionItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

            content
        }
        .background(AppColor.background.ignoresSafeArea())
        .sheet(
            isPresented: $viewModel.isSearchPresented,
            onDismiss: handleSearchDismissed
        ) {
            searchSheet
        }
        .sheet(item: $viewModel.presentedProgramDetail) { detail in
            programDetailSheet(detail)
        }
        .overlay { sessionConflictOverlay }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                if viewModel.isLoading && viewModel.recommendedPrograms.isEmpty && viewModel.popularPrograms.isEmpty {
                    loadingState
                } else {
                    contentState
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    @ViewBuilder
    private var contentState: some View {
        if let errorMessage = viewModel.errorMessage {
            errorCard(errorMessage)
        }

        tagScroller

        if viewModel.isShowingTagResults {
            tagResultsSection
        } else {
            defaultHomeSections
        }
    }

    private var tagResultsSection: some View {
        popularProgramsSection(
            title: "\(viewModel.selectedTag.title) Programs",
            subtitle: "Programs grouped around the training focus you selected.",
            items: viewModel.tagFilteredPrograms
        )
    }

    private var defaultHomeSections: some View {
        Group {
            programSection(
                title: "Recommended For You",
                subtitle: "Chosen to match your current training style, selected program and workout rhythm.",
                items: viewModel.recommendedPrograms
            )
            popularProgramsSection(
                title: "Popular Programs",
                subtitle: "Popular with other lifters for their clear structure, simple progression and strong results.",
                items: viewModel.popularPrograms
            )
        }
    }

    private var searchSheet: some View {
        SearchProgramsSheet(
            viewModel: viewModel,
            onSelectResult: { item in
                pendingSearchSelection = item
                viewModel.dismissSearch()
            }
        )
    }

    private func programDetailSheet(_ detail: ProgramDetail) -> some View {
        ProgramDetailSheet(
            detail: detail,
            onSelectProgram: {
                Task {
                    await viewModel.selectPresentedProgram()
                }
            },
            onAddToLibrary: {
                viewModel.addPresentedProgramToLibrary()
            },
            onCompleteSession: {
                Task {
                    await viewModel.completePresentedProgramSession()
                }
            },
            onDeleteSession: {
                Task {
                    await viewModel.deletePresentedProgramSession()
                }
            },
            onOpenWorkout: {
                viewModel.dismissProgramDetail()
                onOpenWorkout()
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var sessionConflictOverlay: some View {
        if let conflict = viewModel.programSelectionConflictAlert {
            SessionConflictDialog(
                alert: conflict,
                onFinishSession: {
                    Task {
                        await viewModel.completeActiveSessionAndSelectPendingProgram()
                    }
                },
                onCancelSession: {
                    Task {
                        await viewModel.cancelActiveSessionAndSelectPendingProgram()
                    }
                },
                onDismiss: {
                    viewModel.cancelProgramSelectionConflict()
                }
            )
        }
    }

    private var header: some View {
        AppHeaderView(
            title: "Home",
            actions: [.search, .profile],
            onAction: handleHeaderAction
        )
    }

    private func handleHeaderAction(_ action: HeaderAction) {
        switch action {
        case .search:
            viewModel.presentSearch()
        case .profile, .add, .more:
            onHeaderAction(action)
        }
    }

    private func handleSearchDismissed() {
        viewModel.searchQuery = ""

        guard let pendingSearchSelection else { return }
        self.pendingSearchSelection = nil

        Task {
            await presentProgramDetail(pendingSearchSelection)
        }
    }

    private func presentProgramDetail(_ item: ProgramSectionItem) async {
        await viewModel.presentProgramDetail(for: item)
    }

    private var loadingState: some View {
        AppMessageCard(
            title: "Loading home",
            message: "Preparing your recommendations and featured programs."
        ) {
            SwiftUI.ProgressView()
        }
    }

    private func errorCard(_ message: String) -> some View {
        AppMessageCard(
            title: "Something went wrong",
            message: message
        )
    }

    private var tagScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.availableTags) { tag in
                    AppChipView(
                        title: tag.title,
                        isSelected: viewModel.selectedTag == tag
                    ) {
                        viewModel.selectTag(tag)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private func programSection(
        title: String,
        subtitle: String,
        items: [ProgramSectionItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppSectionHeaderView(title: title, subtitle: subtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(items) { item in
                        ProgramCardView(item: item) {
                            Task {
                                await presentProgramDetail(item)
                            }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
        }
    }

    private func popularProgramsSection(
        title: String,
        subtitle: String,
        items: [ProgramSectionItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppSectionHeaderView(title: title, subtitle: subtitle)

            VStack(spacing: AppSpacing.md) {
                ForEach(items) { item in
                    PopularProgramRow(item: item) {
                        Task {
                            await presentProgramDetail(item)
                        }
                    }
                }
            }
        }
    }
}
