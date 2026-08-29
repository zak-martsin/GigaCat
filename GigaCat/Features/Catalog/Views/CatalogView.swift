import SwiftUI

struct CatalogView: View {
    @ObservedObject var viewModel: CatalogViewModel
    let onOpenWorkout: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppHeaderView(
                title: "Catalog",
                actions: [.profile]
            ) { _ in
                onOpenProfile()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)

            content
        }
        .background(AppColor.background.ignoresSafeArea())
        .sheet(item: $viewModel.presentedProgramDetail) { detail in
            programDetailSheet(detail)
        }
        .overlay { sessionConflictOverlay }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            messageCard(
                title: "Loading catalog",
                message: "Preparing the available workout programs."
            ) {
                SwiftUI.ProgressView()
            }
        } else if let errorMessage = viewModel.errorMessage,
                  viewModel.programs.isEmpty {
            messageCard(
                title: "Catalog unavailable",
                message: errorMessage
            )
        } else if viewModel.programs.isEmpty {
            messageCard(
                title: "No programs available",
                message: "Default programs will appear here after the catalog is restored."
            )
        } else {
            catalogContent
        }
    }

    private var catalogContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                filterScroller

                if let errorMessage = viewModel.errorMessage {
                    AppMessageCard(
                        title: "Could not refresh catalog",
                        message: errorMessage
                    )
                }

                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.visiblePrograms) { item in
                        CatalogProgramRow(item: item) {
                            Task {
                                await viewModel.presentProgramDetail(for: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var filterScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.availableFilters) { filter in
                    AppChipView(
                        title: filter.title,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectFilter(filter)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .scrollClipDisabled()
    }

    private func programDetailSheet(_ detail: ProgramDetail) -> some View {
        ProgramDetailSheet(
            detail: detail,
            onSelectProgram: {
                Task {
                    await viewModel.selectPresentedProgram()
                }
            },
            onCompleteSession: {
                Task {
                    await viewModel.completePresentedProgramSession()
                }
            },
            onDeleteSession: {
                Task {
                    await viewModel.cancelPresentedProgramSession()
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
        if let alert = viewModel.programSelectionConflictAlert {
            SessionConflictDialog(
                alert: alert,
                onFinishSession: {
                    Task {
                        await viewModel.finishSessionAndSelectPendingProgram()
                    }
                },
                onCancelSession: {
                    Task {
                        await viewModel.cancelSessionAndSelectPendingProgram()
                    }
                },
                onDismiss: viewModel.cancelSelectionConflict
            )
        }
    }

    private func messageCard<Accessory: View>(
        title: String,
        message: String,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) -> some View {
        AppMessageCard(title: title, message: message, accessory: accessory)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
    }

    private func messageCard(
        title: String,
        message: String
    ) -> some View {
        AppMessageCard(title: title, message: message)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
    }
}
