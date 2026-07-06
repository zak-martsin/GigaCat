import SwiftUI

struct SearchProgramsSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    let onSelectResult: (ProgramSectionItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if trimmedQuery.isEmpty {
                        searchPrompt
                    } else if viewModel.searchResults.isEmpty {
                        emptyResults
                    } else {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.searchResults) { item in
                                PopularProgramRow(item: item) {
                                    onSelectResult(item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search programs"
            )
        }
    }

    private var trimmedQuery: String {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchPrompt: some View {
        AppMessageCard(
            title: "Find your next program",
            message: "Search by title, description, or training tags like strength, home, cardio, or mobility."
        )
    }

    private var emptyResults: some View {
        AppMessageCard(
            title: "No programs found",
            message: "Try a different keyword or training tag."
        )
    }
}
