import Foundation

/// Builds Home-specific view data from repository-backed domain state.
protocol HomePresentationServicing: Sendable {
    func makeProgramItems(
        from catalog: [HomeProgramCatalogEntry],
        selectedProgramID: UUID?
    ) async throws -> [ProgramSectionItem]

    func makeSelectedProgramSummary(
        selectedProgramID: UUID?,
        catalog: [HomeProgramCatalogEntry],
        user: User?
    ) async throws -> SelectedProgramSummary?

    func makeMiniPlayerPresentation(
        user: User,
        selectedProgramID: UUID?,
        programs: [WorkoutProgram],
        sessionExpirationInterval: TimeInterval
    ) async throws -> MiniPlayerPresentation

    func makeProgramDetail(
        for item: ProgramSectionItem,
        selectedProgram: SelectedProgramSummary?,
        miniPlayerContext: MiniPlayerContext
    ) async throws -> ProgramDetail
}

/// Central place for composing Home presentation state that depends on multiple repositories.
struct HomePresentationService: HomePresentationServicing {
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository
    private let mapper: HomeViewDataMapping

    init(
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        mapper: HomeViewDataMapping = HomeViewDataMapper()
    ) {
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
        self.mapper = mapper
    }

    func makeProgramItems(
        from catalog: [HomeProgramCatalogEntry],
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
        catalog: [HomeProgramCatalogEntry],
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

    func makeMiniPlayerPresentation(
        user: User,
        selectedProgramID: UUID?,
        programs: [WorkoutProgram],
        sessionExpirationInterval: TimeInterval
    ) async throws -> MiniPlayerPresentation {
        if let activeSession = try await workoutRepository.activeSession(for: user.id),
           let activeWorkoutDay = try await workoutProgramRepository.fetchWorkoutDay(id: activeSession.workoutDayId),
           let activeProgram = try await workoutProgramRepository.fetchProgram(id: activeWorkoutDay.programId) {
            let plannedExercises = try await workoutProgramRepository.fetchWorkoutDayExercises(
                workoutDayId: activeWorkoutDay.id
            )
            let logs = try await workoutRepository.fetchExerciseLogs(sessionId: activeSession.id)
            let completionPercentage = Self.completionPercentage(
                plannedExercises: plannedExercises,
                logs: logs
            ) ?? 0
            let lastActivityAt = Self.lastActivityDate(
                for: activeSession,
                logs: logs
            )
            let isExpired = Date().timeIntervalSince(lastActivityAt) > sessionExpirationInterval

            return mapper.mapMiniPlayerPresentationForActiveSession(
                session: activeSession,
                programTitle: activeProgram.title,
                workoutDayTitle: activeWorkoutDay.title,
                completionPercentage: completionPercentage,
                isExpired: isExpired
            )
        }

        guard let selectedProgramID,
              let selectedProgram = programs.first(where: { $0.id == selectedProgramID }) else {
            return mapper.mapMiniPlayerPresentationForNoProgramSelected()
        }

        let days = try await workoutProgramRepository.fetchWorkoutDays(programId: selectedProgram.id)
        guard !days.isEmpty else {
            return mapper.mapMiniPlayerPresentationForProgramWithoutDays(
                programTitle: selectedProgram.title
            )
        }

        let allSessions = try await workoutRepository.fetchSessions(for: user.id)
        let selectedProgramDayIDs = Set(days.map(\.id))
        let completedSessions = allSessions.filter {
            $0.status == .completed && selectedProgramDayIDs.contains($0.workoutDayId)
        }
        let sortedCompletedSessions = completedSessions.sorted { lhs, rhs in
            let lhsCompletedAt = lhs.completedAt ?? lhs.startedAt
            let rhsCompletedAt = rhs.completedAt ?? rhs.startedAt

            if lhsCompletedAt == rhsCompletedAt {
                return lhs.startedAt > rhs.startedAt
            }

            return lhsCompletedAt > rhsCompletedAt
        }
        let nextWorkoutDay = Self.nextWorkoutDay(days: days, completedSessions: sortedCompletedSessions) ?? days[0]

        return mapper.mapMiniPlayerPresentationForReadyToStart(
            programTitle: selectedProgram.title,
            workoutDayID: nextWorkoutDay.id,
            workoutDayTitle: nextWorkoutDay.title
        )
    }

    func makeProgramDetail(
        for item: ProgramSectionItem,
        selectedProgram: SelectedProgramSummary?,
        miniPlayerContext: MiniPlayerContext
    ) async throws -> ProgramDetail {
        let days = try await workoutProgramRepository.fetchWorkoutDays(programId: item.id)

        return mapper.mapProgramDetail(
            item: item,
            primaryAction: Self.primaryAction(
                for: item.id,
                isSelected: item.isSelected,
                selectedProgram: selectedProgram,
                miniPlayerContext: miniPlayerContext
            ),
            progressText: Self.activeProgramProgressText(
                for: item.id,
                selectedProgram: selectedProgram,
                miniPlayerContext: miniPlayerContext
            ),
            hasActiveSession: Self.activeProgramHasSession(
                for: item.id,
                selectedProgram: selectedProgram,
                miniPlayerContext: miniPlayerContext
            ),
            workoutDayTitles: days.map(\.title)
        )
    }

    /// Calculates workout completion by comparing planned sets against unique logged set numbers.
    nonisolated static func completionPercentage(
        plannedExercises: [WorkoutDayExercise],
        logs: [ExerciseLog]
    ) -> Int? {
        let plannedSetCountByWorkoutDayExerciseID = plannedExercises.reduce(into: [UUID: Int]()) { partialResult, exercise in
            partialResult[exercise.id] = exercise.targetSets
        }

        let totalPlannedSets = plannedSetCountByWorkoutDayExerciseID.values.reduce(0, +)
        guard totalPlannedSets > 0 else { return nil }

        let uniqueCompletedSetCountByWorkoutDayExerciseID = Dictionary(grouping: logs) { $0.workoutDayExerciseId }
            .reduce(into: [UUID: Int]()) { partialResult, element in
                guard plannedSetCountByWorkoutDayExerciseID[element.key] != nil else { return }
                partialResult[element.key] = Set(element.value.map(\.setNumber)).count
            }

        let completedSets = uniqueCompletedSetCountByWorkoutDayExerciseID.reduce(into: 0) { partialResult, element in
            let plannedSetCount = plannedSetCountByWorkoutDayExerciseID[element.key] ?? 0
            partialResult += min(element.value, plannedSetCount)
        }

        let progress = Double(completedSets) / Double(totalPlannedSets)
        return Int((progress * 100).rounded())
    }

    /// Picks the workout day that should follow the most recently completed session for the selected program.
    nonisolated static func nextWorkoutDay(
        days: [WorkoutDay],
        completedSessions: [WorkoutSession]
    ) -> WorkoutDay? {
        guard let firstDay = days.first else { return nil }
        guard let latestCompletedSession = completedSessions.first else { return firstDay }
        guard let currentIndex = days.firstIndex(where: { $0.id == latestCompletedSession.workoutDayId }) else {
            return firstDay
        }

        let nextIndex = (currentIndex + 1) % days.count
        return days[nextIndex]
    }

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
        guard let completionPercentage = Self.completionPercentage(
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

    // MARK: - Detail Presentation Rules

    private nonisolated static func primaryAction(
        for programID: UUID,
        isSelected: Bool,
        selectedProgram: SelectedProgramSummary?,
        miniPlayerContext: MiniPlayerContext
    ) -> ProgramDetail.PrimaryAction {
        guard isSelected else {
            return .chooseProgram
        }

        if case .activeSession(_, _, _, _) = miniPlayerContext,
           selectedProgram?.id == programID {
            return .continueWorkout
        }

        return .startWorkout
    }

    private nonisolated static func activeProgramProgressText(
        for programID: UUID,
        selectedProgram: SelectedProgramSummary?,
        miniPlayerContext: MiniPlayerContext
    ) -> String? {
        guard selectedProgram?.id == programID else { return nil }

        switch miniPlayerContext {
        case .activeSession(_, _, _, _):
            return selectedProgram?.progressText
        case .noProgramSelected, .readyToStart:
            return nil
        }
    }

    private nonisolated static func activeProgramHasSession(
        for programID: UUID,
        selectedProgram: SelectedProgramSummary?,
        miniPlayerContext: MiniPlayerContext
    ) -> Bool {
        guard selectedProgram?.id == programID else { return false }

        if case .activeSession(_, _, _, _) = miniPlayerContext {
            return true
        }

        return false
    }

    /// Uses the latest exercise log when available so session expiration tracks real workout activity.
    private nonisolated static func lastActivityDate(
        for session: WorkoutSession,
        logs: [ExerciseLog]
    ) -> Date {
        logs.map(\.performedAt).max() ?? session.startedAt
    }
}
