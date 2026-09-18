import Foundation

protocol CatalogPresentationServicing {
    func makeItems(
        from catalog: [ProgramCatalogEntry],
        selectedProgramID: UUID?
    ) async throws -> [CatalogProgramItem]

    func availableFilters(in items: [CatalogProgramItem]) -> [CatalogFilter]
    func items(in items: [CatalogProgramItem], matching filter: CatalogFilter) -> [CatalogProgramItem]
}

/// Builds Catalog view data and owns its local tag-filtering rules.
struct CatalogPresentationService: CatalogPresentationServicing {
    private let workoutProgramRepository: WorkoutProgramRepository
    private let preferredTagOrder: [WorkoutProgramTag] = [
        .streetWorkout,
        .gym,
        .home,
        .cardio,
        .strength,
        .muscleGain,
        .mobility,
        .hiit,
        .bodyweight
    ]

    init(workoutProgramRepository: WorkoutProgramRepository) {
        self.workoutProgramRepository = workoutProgramRepository
    }

    func makeItems(
        from catalog: [ProgramCatalogEntry],
        selectedProgramID: UUID?
    ) async throws -> [CatalogProgramItem] {
        var items: [CatalogProgramItem] = []

        for entry in catalog {
            let days = try await workoutProgramRepository.fetchWorkoutDays(
                programId: entry.program.id
            )
            var exerciseCount = 0

            for day in days {
                exerciseCount += try await workoutProgramRepository
                    .fetchWorkoutDayExercises(workoutDayId: day.id)
                    .count
            }

            items.append(
                CatalogProgramItem(
                    id: entry.program.id,
                    title: entry.program.title,
                    description: entry.program.description,
                    dayCount: days.count,
                    exerciseCount: exerciseCount,
                    isSelected: selectedProgramID == entry.program.id,
                    tags: entry.program.tags
                )
            )
        }

        return items.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func availableFilters(in items: [CatalogProgramItem]) -> [CatalogFilter] {
        let usedTags = Set(items.flatMap(\.tags))
        return [.all] + preferredTagOrder
            .filter(usedTags.contains)
            .map(CatalogFilter.tag)
    }

    func items(
        in items: [CatalogProgramItem],
        matching filter: CatalogFilter
    ) -> [CatalogProgramItem] {
        guard case .tag(let tag) = filter else { return items }
        return items.filter { $0.tags.contains(tag) }
    }
}
