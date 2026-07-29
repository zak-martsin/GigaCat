import Foundation

protocol HomeViewDataMapping: Sendable {
    func mapProgramSectionItem(
        entry: ProgramCatalogEntry,
        dayCount: Int,
        exerciseCount: Int,
        selectedProgramID: UUID?
    ) -> ProgramSectionItem

    func mapSelectedProgramSummary(
        entry: ProgramCatalogEntry,
        dayCount: Int,
        nextWorkoutTitle: String?,
        progressText: String?
    ) -> SelectedProgramSummary
}

struct HomeViewDataMapper: HomeViewDataMapping {
    func mapProgramSectionItem(
        entry: ProgramCatalogEntry,
        dayCount: Int,
        exerciseCount: Int,
        selectedProgramID: UUID?
    ) -> ProgramSectionItem {
        ProgramSectionItem(
            id: entry.program.id,
            title: entry.program.title,
            description: entry.program.description,
            dayCount: dayCount,
            exerciseCount: exerciseCount,
            rateScore: entry.rateScore,
            isSelected: selectedProgramID == entry.program.id,
            isRecommended: entry.isRecommended,
            isPopular: entry.isPopular,
            tags: entry.program.tags
        )
    }

    func mapSelectedProgramSummary(
        entry: ProgramCatalogEntry,
        dayCount: Int,
        nextWorkoutTitle: String?,
        progressText: String?
    ) -> SelectedProgramSummary {
        SelectedProgramSummary(
            id: entry.program.id,
            title: entry.program.title,
            subtitle: "\(dayCount) workout days",
            nextWorkoutTitle: nextWorkoutTitle,
            progressText: progressText
        )
    }

}
