import Foundation

/// Builds Home-specific view data from repository-backed domain state.
protocol HomePresentationServicing: Sendable {
    func makeProgramItems(
        from catalog: [ProgramCatalogEntry],
        selectedProgramID: UUID?
    ) async throws -> [ProgramSectionItem]

    func makeSelectedProgramSummary(
        selectedProgramID: UUID?,
        catalog: [ProgramCatalogEntry],
        user: User?
    ) async throws -> SelectedProgramSummary?
}

/// Central place for composing Home presentation state that depends on multiple repositories.
struct HomePresentationService: HomePresentationServicing {
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository
    private let mapper: HomeViewDataMapping

    // MARK: - Initialization

    init(
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        mapper: HomeViewDataMapping = HomeViewDataMapper()
    ) {
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
        self.mapper = mapper
    }

    // MARK: - Catalog Presentation

    func makeProgramItems(
        from catalog: [ProgramCatalogEntry],
        selectedProgramID: UUID?
    ) async throws -> [ProgramSectionItem] {
        var items: [ProgramSectionItem] = []

        for entry in catalog {
            let days = try await workoutProgramRepository.fetchWorkoutDays(programId: entry.program.id)
            let exerciseCount = try await totalExerciseCount(for: days)
            items.append(
                mapper.mapProgramSectionItem(
                    entry: entry,
                    dayCount: days.count,
                    exerciseCount: exerciseCount,
                    selectedProgramID: selectedProgramID
                )
            )
        }

        return items.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func makeSelectedProgramSummary(
        selectedProgramID: UUID?,
        catalog: [ProgramCatalogEntry],
        user: User?
    ) async throws -> SelectedProgramSummary? {
        guard let selectedProgramID else { return nil }
        guard let entry = catalog.first(where: { $0.id == selectedProgramID }) else { return nil }
        guard let user else { return nil }

        let days = try await workoutProgramRepository.fetchWorkoutDays(programId: selectedProgramID)
        let progressState = try await activeSessionProgressState(
            userID: user.id,
            days: days
        )

        return mapper.mapSelectedProgramSummary(
            entry: entry,
            dayCount: days.count,
            nextWorkoutTitle: progressState?.workoutDayTitle ?? days.first?.title,
            progressText: progressState?.progressText
        )
    }

    // MARK: - Progress Helpers

    // MARK: - Private Helpers

    private func totalExerciseCount(for days: [WorkoutDay]) async throws -> Int {
        var count = 0

        for day in days {
            let exercises = try await workoutProgramRepository.fetchWorkoutDayExercises(workoutDayId: day.id)
            count += exercises.count
        }

        return count
    }

    private func activeSessionProgressState(
        userID: UUID,
        days: [WorkoutDay]
    ) async throws -> ActiveSessionProgressState? {
        guard let activeSession = try await workoutRepository.activeSession(for: userID) else {
            return nil
        }

        guard let workoutDay = days.first(where: { $0.id == activeSession.workoutDayId }) else {
            return nil
        }

        let plannedExercises = try await workoutProgramRepository.fetchWorkoutDayExercises(
            workoutDayId: workoutDay.id
        )
        let logs = try await workoutRepository.fetchExerciseLogs(sessionId: activeSession.id)
        guard let completionPercentage = MiniPlayerService.completionPercentage(
            plannedExercises: plannedExercises,
            logs: logs
        ) else {
            return nil
        }

        return ActiveSessionProgressState(
            workoutDayTitle: workoutDay.title,
            progressText: "\(workoutDay.title) • \(completionPercentage)% completed"
        )
    }
}
