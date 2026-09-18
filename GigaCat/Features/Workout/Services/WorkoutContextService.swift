import Foundation

/// Resolves the program and workout day that should be shown when Workout opens.
protocol WorkoutContextServicing {
    func loadContext() async throws -> WorkoutContext?
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
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository

    init(
        userRepository: UserRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository
    ) {
        self.userRepository = userRepository
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
    }

    // MARK: - Context Loading

    func loadContext() async throws -> WorkoutContext? {
        guard let user = try await userRepository.currentUser() else {
            throw WorkoutContextError.currentUserNotFound
        }

        if let activeSession = try await workoutRepository.activeSession(for: user.id) {
            return try await makeActiveSessionContext(
                for: activeSession,
                userID: user.id
            )
        }

        guard let selectedProgramID = user.selectedProgramId else {
            return nil
        }
        guard let program = try await workoutProgramRepository.fetchProgram(
            id: selectedProgramID
        ) else {
            throw WorkoutContextError.programNotFound
        }

        let completedSessions = try await workoutRepository.fetchSessions(for: user.id)
            .filter { $0.status == .completed }
            .sorted(by: Self.isMoreRecent)
        let latestSession = completedSessions.first
        let latestWorkoutDay = try await workoutDay(for: latestSession)
        let days = try await orderedDays(for: program.id, includeInactive: false)
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

    // MARK: - Context Assembly

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

        let days = try await orderedDays(for: program.id, includeInactive: true)
        guard days.contains(where: { $0.id == activeWorkoutDay.id }) else {
            throw WorkoutContextError.workoutDayNotFound
        }
        let dayContents = try await makeDayContents(from: days, includeInactive: true)

        return WorkoutContext(
            userID: userID,
            program: program,
            dayContents: dayContents,
            initialDayID: activeWorkoutDay.id,
            activeSession: activeSession
        )
    }

    // MARK: - Program and Day Resolution

    private func workoutDay(for session: WorkoutSession?) async throws -> WorkoutDay? {
        guard let session else { return nil }
        return try await workoutProgramRepository.fetchWorkoutDay(id: session.workoutDayId)
    }

    private func orderedDays(
        for programID: UUID,
        includeInactive: Bool
    ) async throws -> [WorkoutDay] {
        let fetchedDays: [WorkoutDay]
        if includeInactive {
            fetchedDays = try await workoutProgramRepository.fetchWorkoutDaysForHistory(
                programId: programID
            )
        } else {
            fetchedDays = try await workoutProgramRepository.fetchWorkoutDays(
                programId: programID
            )
        }
        let days = fetchedDays.sorted { $0.orderIndex < $1.orderIndex }

        guard !days.isEmpty else {
            throw WorkoutContextError.programHasNoWorkoutDays
        }

        return days
    }

    // MARK: - Day Content

    private func makeDayContents(
        from days: [WorkoutDay],
        includeInactive: Bool = false
    ) async throws -> [WorkoutDayContent] {
        var dayContents: [WorkoutDayContent] = []

        for day in days {
            let dayExercises: [WorkoutDayExercise]
            if includeInactive {
                dayExercises = try await workoutProgramRepository
                    .fetchWorkoutDayExercisesForHistory(workoutDayId: day.id)
            } else {
                dayExercises = try await workoutProgramRepository
                    .fetchWorkoutDayExercises(workoutDayId: day.id)
            }
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

    // MARK: - Ordering Helpers

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
