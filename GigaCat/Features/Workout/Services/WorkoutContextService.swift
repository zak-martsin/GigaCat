import Foundation

/// Resolves the program and workout day that should be shown when Workout opens.
protocol WorkoutContextServicing: Sendable {
    func loadContext() async throws -> WorkoutContext
}

enum WorkoutContextError: Error, Equatable {
    case currentUserNotFound
    case programNotFound
    case workoutDayNotFound
    case programHasNoWorkoutDays
    case exerciseNotFound
}

struct WorkoutContextService: WorkoutContextServicing {
    private let userRepository: UserRepository
    private let programCatalogRepository: ProgramCatalogRepository
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository

    init(
        userRepository: UserRepository,
        programCatalogRepository: ProgramCatalogRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository
    ) {
        self.userRepository = userRepository
        self.programCatalogRepository = programCatalogRepository
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
    }

    func loadContext() async throws -> WorkoutContext {
        guard let user = try await userRepository.currentUser() else {
            throw WorkoutContextError.currentUserNotFound
        }

        if let activeSession = try await workoutRepository.activeSession(for: user.id) {
            return try await makeActiveSessionContext(
                for: activeSession,
                userID: user.id
            )
        }

        let completedSessions = try await workoutRepository.fetchSessions(for: user.id)
            .filter { $0.status == .completed }
            .sorted(by: Self.isMoreRecent)
        let latestSession = completedSessions.first
        let latestWorkoutDay = try await workoutDay(for: latestSession)
        let program = try await resolveProgram(
            selectedProgramID: user.selectedProgramId,
            latestWorkoutDay: latestWorkoutDay
        )
        let days = try await orderedDays(for: program.id)
        let initialDay = Self.initialDay(
            in: days,
            latestWorkoutDay: latestWorkoutDay
        )
        let dayContents = try await makeDayContents(from: days)

        return WorkoutContext(
            userID: user.id,
            program: program,
            dayContents: dayContents,
            initialDayID: initialDay.id,
            activeSession: nil
        )
    }

    private func makeActiveSessionContext(
        for activeSession: WorkoutSession,
        userID: UUID
    ) async throws -> WorkoutContext {
        guard let activeWorkoutDay = try await workoutProgramRepository.fetchWorkoutDay(
            id: activeSession.workoutDayId
        ) else {
            throw WorkoutContextError.workoutDayNotFound
        }

        guard let program = try await workoutProgramRepository.fetchProgram(id: activeWorkoutDay.programId) else {
            throw WorkoutContextError.programNotFound
        }

        let days = try await orderedDays(for: program.id)
        guard days.contains(where: { $0.id == activeWorkoutDay.id }) else {
            throw WorkoutContextError.workoutDayNotFound
        }
        let dayContents = try await makeDayContents(from: days)

        return WorkoutContext(
            userID: userID,
            program: program,
            dayContents: dayContents,
            initialDayID: activeWorkoutDay.id,
            activeSession: activeSession
        )
    }

    private func resolveProgram(
        selectedProgramID: UUID?,
        latestWorkoutDay: WorkoutDay?
    ) async throws -> WorkoutProgram {
        if let selectedProgramID,
           let selectedProgram = try await workoutProgramRepository.fetchProgram(id: selectedProgramID) {
            return selectedProgram
        }

        if let latestWorkoutDay,
           let latestProgram = try await workoutProgramRepository.fetchProgram(id: latestWorkoutDay.programId) {
            return latestProgram
        }

        let catalog = try await programCatalogRepository.fetchProgramCatalog()
        guard let recommendedProgram = catalog.first(where: \.isRecommended)?.program else {
            throw WorkoutContextError.programNotFound
        }

        return recommendedProgram
    }

    private func workoutDay(for session: WorkoutSession?) async throws -> WorkoutDay? {
        guard let session else { return nil }
        return try await workoutProgramRepository.fetchWorkoutDay(id: session.workoutDayId)
    }

    private func orderedDays(for programID: UUID) async throws -> [WorkoutDay] {
        let days = try await workoutProgramRepository.fetchWorkoutDays(programId: programID)
            .sorted { $0.orderIndex < $1.orderIndex }

        guard !days.isEmpty else {
            throw WorkoutContextError.programHasNoWorkoutDays
        }

        return days
    }

    private func makeDayContents(from days: [WorkoutDay]) async throws -> [WorkoutDayContent] {
        var dayContents: [WorkoutDayContent] = []

        for day in days {
            let dayExercises = try await workoutProgramRepository.fetchWorkoutDayExercises(
                workoutDayId: day.id
            )
            var exerciseContents: [WorkoutExerciseContent] = []

            for dayExercise in dayExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard let exercise = try await workoutProgramRepository.fetchExercise(
                    id: dayExercise.exerciseId
                ) else {
                    throw WorkoutContextError.exerciseNotFound
                }

                exerciseContents.append(
                    WorkoutExerciseContent(
                        dayExercise: dayExercise,
                        exercise: exercise
                    )
                )
            }

            dayContents.append(
                WorkoutDayContent(
                    day: day,
                    exercises: exerciseContents
                )
            )
        }

        return dayContents
    }

    private static func initialDay(
        in days: [WorkoutDay],
        latestWorkoutDay: WorkoutDay?
    ) -> WorkoutDay {
        guard let latestWorkoutDay,
              latestWorkoutDay.programId == days[0].programId,
              let latestIndex = days.firstIndex(where: { $0.id == latestWorkoutDay.id }) else {
            return days[0]
        }

        return days[(latestIndex + 1) % days.count]
    }

    private static func isMoreRecent(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt

        if lhsDate == rhsDate {
            return lhs.startedAt > rhs.startedAt
        }

        return lhsDate > rhsDate
    }
}
