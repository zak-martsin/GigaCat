import SwiftUI

struct LibraryView: View {
    let viewModel: LibraryViewModel
    let onOpenWorkout: () -> Void
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

            content
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .background(AppColor.background.ignoresSafeArea())
        .sheet(item: presentedProgramDetail) { detail in
            ProgramDetailSheet(
                detail: detail,
                onSelectProgram: {
                    Task {
                        await viewModel.selectPresentedProgram()
                    }
                },
                onAddToLibrary: {},
                onRemoveFromLibrary: {
                    Task {
                        await viewModel.removePresentedProgramFromLibrary()
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
        .overlay {
            programSelectionConflictOverlay
        }
        .alert(
            "Couldn’t remove program",
            isPresented: removalErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.removalErrorMessage ?? "Please try again.")
        }
        .alert(
            "Program unavailable",
            isPresented: programDetailErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.programDetailErrorMessage ?? "Please try again.")
        }
    }

    // MARK: - Header

    private var header: some View {
        AppHeaderView(
            title: "Library",
            actions: [.add, .profile],
            onAction: onHeaderAction
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            messageCard(
                title: "Loading library",
                message: "Preparing your saved workout programs."
            ) {
                SwiftUI.ProgressView()
            }
        case .loaded:
            programList
        case .empty:
            messageCard(
                title: "Your library is empty",
                message: "Programs you save from the catalog will appear here."
            )
        case .failed:
            messageCard(
                title: "Library unavailable",
                message: "Your saved programs couldn’t be loaded."
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

    private var programList: some View {
        List {
            ForEach(viewModel.programs) { program in
                Button {
                    Task {
                        await viewModel.presentProgramDetail(for: program.id)
                    }
                } label: {
                    LibraryProgramRow(program: program)
                }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(
                            top: AppSpacing.sm,
                            leading: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                            trailing: AppSpacing.lg
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", role: .destructive) {
                            Task {
                                await viewModel.removeProgram(program.id)
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var programSelectionConflictOverlay: some View {
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
                onDismiss: viewModel.cancelProgramSelectionConflict
            )
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

    private var removalErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.removalErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissRemovalError()
                }
            }
        )
    }

    private var programDetailErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.programDetailErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissProgramDetailError()
                }
            }
        )
    }

    private var presentedProgramDetail: Binding<ProgramDetail?> {
        Binding(
            get: { viewModel.presentedProgramDetail },
            set: { detail in
                if detail == nil {
                    viewModel.dismissProgramDetail()
                }
            }
        )
    }
}

private struct LibraryProgramRow: View {
    let program: WorkoutProgram

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ProgramArtworkPlaceholderView(
                cornerRadius: AppRadius.md,
                height: AppControlSize.libraryProgramArtwork,
                width: AppControlSize.libraryProgramArtwork
            )

            Text(program.title)
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .appCardStyle(cornerRadius: AppRadius.md)
        .accessibilityElement(children: .combine)
    }
}
