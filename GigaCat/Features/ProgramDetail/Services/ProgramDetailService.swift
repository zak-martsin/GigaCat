import Foundation

enum ProgramDetailSelectionResult {
    case switched(User)
    case blocked(pendingProgramID: UUID, alert: ProgramSelectionConflictAlert)
}

enum ProgramDetailConflictResolution {
    case finishSession
    case cancelSession
}

/// Shared program-detail operations used without coupling the presenting feature to Catalog.
protocol ProgramDetailServicing {
    func makeDetail(for programID: UUID, user: User) async throws -> ProgramDetail
    func selectProgram(_ programID: UUID, for user: User) async throws -> ProgramDetailSelectionResult
    func resolveSelectionConflict(
        selecting programID: UUID,
        for user: User,
        resolution: ProgramDetailConflictResolution
    ) async throws -> User
    func completeActiveSession(for programID: UUID, userID: UUID) async throws -> Bool
    func cancelActiveSession(for programID: UUID, userID: UUID) async throws -> Bool
}

/// Coordinates repository data and mutations required by the reusable program-detail flow.
struct ProgramDetailService: ProgramDetailServicing {
    private let userRepository: UserRepository
    private let defaultProgramCatalogRepository: DefaultProgramCatalogRepository
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository

    init(
        userRepository: UserRepository,
        defaultProgramCatalogRepository: DefaultProgramCatalogRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository
    ) {
        self.userRepository = userRepository
        self.defaultProgramCatalogRepository = defaultProgramCatalogRepository
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
    }

    // MARK: - Presentation

    func makeDetail(for programID: UUID, user: User) async throws -> ProgramDetail {
        let catalog = try await defaultProgramCatalogRepository.fetchProgramCatalog()
        let catalogProgram = catalog.first(where: { $0.id == programID })?.program
        let program: WorkoutProgram
        if let catalogProgram {
            program = catalogProgram
        } else if let storedProgram = try await workoutProgramRepository.fetchProgram(
            id: programID
        ) {
            program = storedProgram
        } else {
            throw RepositoryError.workoutProgramNotFound
        }

        let isVisibleInCatalog = catalogProgram != nil
        let days = try await workoutDays(
            programID: programID,
            includeInactive: !isVisibleInCatalog
        )
        let exerciseCount = try await totalExerciseCount(
            for: days,
            includeInactive: !isVisibleInCatalog
        )
        let activeSessionContext = try await activeSessionContext(for: user.id)
        let hasActiveSession = activeSessionContext?.programID == programID
        let progressText = try await progressText(
            for: activeSessionContext,
            presentedProgramID: programID
        )
        let isSelected = user.selectedProgramId == programID

        return ProgramDetail(
            id: program.id,
            artwork: program.artwork,
            title: program.title,
            description: program.description,
            dayCount: days.count,
            exerciseCount: exerciseCount,
            isSelected: isSelected,
            primaryAction: primaryAction(
                isSelected: isSelected,
                hasActiveSession: hasActiveSession
            ),
            progressText: progressText,
            hasActiveSession: hasActiveSession,
            tags: program.tags,
            workoutDayTitles: days.map(\.title)
        )
    }

    // MARK: - Selection

    func selectProgram(
        _ programID: UUID,
        for user: User
    ) async throws -> ProgramDetailSelectionResult {
        if let context = try await activeSessionContext(for: user.id),
           context.programID != programID {
            return .blocked(
                pendingProgramID: programID,
                alert: ProgramSelectionConflictAlert(
                    id: context.session.id,
                    title: "Unfinished Workout In Progress",
                    message: "You already have an active workout session. " +
                        "Please review it before switching programs.",
                    currentProgramTitle: context.programTitle,
                    currentWorkoutDayTitle: context.workoutDay.title
                )
            )
        }

        let updatedUser = try await userRepository.updateSelectedProgram(
            for: user.id,
            programId: programID
        )
        return .switched(updatedUser)
    }

    func resolveSelectionConflict(
        selecting programID: UUID,
        for user: User,
        resolution: ProgramDetailConflictResolution
    ) async throws -> User {
        guard let context = try await activeSessionContext(for: user.id) else {
            return try await userRepository.updateSelectedProgram(
                for: user.id,
                programId: programID
            )
        }

        switch resolution {
        case .finishSession:
            return try await workoutRepository.completeSessionAndSelectProgram(
                sessionId: context.session.id,
                completedAt: Date(),
                userId: user.id,
                programId: programID
            )
        case .cancelSession:
            return try await workoutRepository.deleteSessionAndSelectProgram(
                sessionId: context.session.id,
                userId: user.id,
                programId: programID
            )
        }
    }

    // MARK: - Session Actions

    func completeActiveSession(
        for programID: UUID,
        userID: UUID
    ) async throws -> Bool {
        guard let context = try await activeSessionContext(for: userID),
              context.programID == programID else {
            return false
        }

        _ = try await workoutRepository.completeSession(
            sessionId: context.session.id,
            userId: userID,
            completedAt: Date()
        )
        return true
    }

    func cancelActiveSession(
        for programID: UUID,
        userID: UUID
    ) async throws -> Bool {
        guard let context = try await activeSessionContext(for: userID),
              context.programID == programID else {
            return false
        }

        try await workoutRepository.deleteSession(
            sessionId: context.session.id,
            userId: userID
        )
        return true
    }

    // MARK: - Helpers

    private func workoutDays(
        programID: UUID,
        includeInactive: Bool
    ) async throws -> [WorkoutDay] {
        if includeInactive {
            return try await workoutProgramRepository.fetchWorkoutDaysForHistory(
                programId: programID
            )
        }
        return try await workoutProgramRepository.fetchWorkoutDays(programId: programID)
    }

    private func totalExerciseCount(
        for days: [WorkoutDay],
        includeInactive: Bool
    ) async throws -> Int {
        var count = 0

        for day in days {
            let exercises: [WorkoutDayExercise]
            if includeInactive {
                exercises = try await workoutProgramRepository
                    .fetchWorkoutDayExercisesForHistory(workoutDayId: day.id)
            } else {
                exercises = try await workoutProgramRepository
                    .fetchWorkoutDayExercises(workoutDayId: day.id)
            }
            count += exercises.count
        }

        return count
    }

    private func activeSessionContext(for userID: UUID) async throws -> ActiveProgramSessionContext? {
        guard let session = try await workoutRepository.activeSession(for: userID),
              let workoutDay = try await workoutProgramRepository.fetchWorkoutDay(id: session.workoutDayId),
              let program = try await workoutProgramRepository.fetchProgram(id: workoutDay.programId) else {
            return nil
        }

        return ActiveProgramSessionContext(
            session: session,
            workoutDay: workoutDay,
            programID: program.id,
            programTitle: program.title
        )
    }

    private func progressText(
        for context: ActiveProgramSessionContext?,
        presentedProgramID: UUID
    ) async throws -> String? {
        guard let context,
              context.programID == presentedProgramID else {
            return nil
        }

        let plannedExercises = try await workoutProgramRepository.fetchWorkoutDayExercisesForHistory(
            workoutDayId: context.workoutDay.id
        )
        let logs = try await workoutRepository.fetchExerciseLogs(sessionId: context.session.id)
        guard let percentage = completionPercentage(
            plannedExercises: plannedExercises,
            logs: logs
        ) else {
            return nil
        }

        return "\(context.workoutDay.title) • \(percentage)% completed"
    }

    private func primaryAction(
        isSelected: Bool,
        hasActiveSession: Bool
    ) -> ProgramDetail.PrimaryAction {
        guard isSelected else { return .chooseProgram }
        return hasActiveSession ? .continueWorkout : .startWorkout
    }

    private func completionPercentage(
        plannedExercises: [WorkoutDayExercise],
        logs: [ExerciseLog]
    ) -> Int? {
        let plannedSetCounts = Dictionary(
            uniqueKeysWithValues: plannedExercises.compactMap { exercise in
                exercise.targetSets.map { (exercise.id, $0) }
            }
        )
        let totalPlannedSets = plannedSetCounts.values.reduce(0, +)
        guard totalPlannedSets > 0 else { return nil }

        let completedSets = Dictionary(grouping: logs, by: \.workoutDayExerciseId)
            .reduce(into: 0) { result, entry in
                guard let plannedCount = plannedSetCounts[entry.key] else { return }
                let completedCount = Set(entry.value.map(\.setNumber)).count
                result += min(completedCount, plannedCount)
            }

        return Int((Double(completedSets) / Double(totalPlannedSets) * 100).rounded())
    }
}

private struct ActiveProgramSessionContext {
    let session: WorkoutSession
    let workoutDay: WorkoutDay
    let programID: UUID
    let programTitle: String
}
