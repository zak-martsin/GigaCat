import Foundation

/// Builds app-level mini-player state from the current repository snapshot.
protocol MiniPlayerServicing: Sendable {
    func makePresentation() async throws -> MiniPlayerPresentation
}

struct MiniPlayerService: MiniPlayerServicing {
    private let userRepository: UserRepository
    private let workoutProgramRepository: WorkoutProgramRepository
    private let workoutRepository: WorkoutRepository
    private let mapper: MiniPlayerMapping
    private let sessionExpirationInterval: TimeInterval
    private let now: @Sendable () -> Date

    init(
        userRepository: UserRepository,
        workoutProgramRepository: WorkoutProgramRepository,
        workoutRepository: WorkoutRepository,
        mapper: MiniPlayerMapping = MiniPlayerMapper(),
        sessionExpirationInterval: TimeInterval = 60 * 60 * 8,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.userRepository = userRepository
        self.workoutProgramRepository = workoutProgramRepository
        self.workoutRepository = workoutRepository
        self.mapper = mapper
        self.sessionExpirationInterval = sessionExpirationInterval
        self.now = now
    }

    func makePresentation() async throws -> MiniPlayerPresentation {
        guard let user = try await userRepository.currentUser() else {
            return mapper.mapNoProgramSelected()
        }

        if let presentation = try await activeSessionPresentation(for: user) {
            return presentation
        }

        guard let selectedProgramID = user.selectedProgramId,
              let program = try await workoutProgramRepository.fetchProgram(id: selectedProgramID) else {
            return mapper.mapNoProgramSelected()
        }

        let days = try await workoutProgramRepository.fetchWorkoutDays(programId: program.id)
        guard !days.isEmpty else {
            return mapper.mapProgramWithoutDays(title: program.title)
        }

        let sessions = try await workoutRepository.fetchSessions(for: user.id)
        let dayIDs = Set(days.map(\.id))
        let completedSessions = sessions
            .filter { $0.status == .completed && dayIDs.contains($0.workoutDayId) }
            .sorted(by: Self.isMoreRecent)
        let nextDay = Self.nextWorkoutDay(days: days, completedSessions: completedSessions) ?? days[0]

        return mapper.mapReadyToStart(
            programTitle: program.title,
            workoutDayID: nextDay.id,
            workoutDayTitle: nextDay.title
        )
    }

    /// Calculates workout completion from planned sets and unique logged set numbers.
    nonisolated static func completionPercentage(
        plannedExercises: [WorkoutDayExercise],
        logs: [ExerciseLog]
    ) -> Int? {
        let plannedSetCounts = Dictionary(
            uniqueKeysWithValues: plannedExercises.map { ($0.id, $0.targetSets) }
        )
        let totalPlannedSets = plannedSetCounts.values.reduce(0, +)
        guard totalPlannedSets > 0 else { return nil }

        let completedSets = Dictionary(grouping: logs, by: \.workoutDayExerciseId)
            .reduce(into: 0) { result, entry in
                guard let plannedCount = plannedSetCounts[entry.key] else { return }
                result += min(Set(entry.value.map(\.setNumber)).count, plannedCount)
            }

        return Int((Double(completedSets) / Double(totalPlannedSets) * 100).rounded())
    }

    /// Picks the workout day following the most recently completed session.
    nonisolated static func nextWorkoutDay(
        days: [WorkoutDay],
        completedSessions: [WorkoutSession]
    ) -> WorkoutDay? {
        guard let firstDay = days.first else { return nil }
        guard let latestSession = completedSessions.first,
              let currentIndex = days.firstIndex(where: { $0.id == latestSession.workoutDayId }) else {
            return firstDay
        }

        return days[(currentIndex + 1) % days.count]
    }

    private func activeSessionPresentation(for user: User) async throws -> MiniPlayerPresentation? {
        guard let session = try await workoutRepository.activeSession(for: user.id),
              let day = try await workoutProgramRepository.fetchWorkoutDay(id: session.workoutDayId),
              let program = try await workoutProgramRepository.fetchProgram(id: day.programId) else {
            return nil
        }

        let plannedExercises = try await workoutProgramRepository.fetchWorkoutDayExercises(
            workoutDayId: day.id
        )
        let logs = try await workoutRepository.fetchExerciseLogs(sessionId: session.id)
        let completion = Self.completionPercentage(
            plannedExercises: plannedExercises,
            logs: logs
        ) ?? 0
        let lastActivityAt = logs.map(\.performedAt).max() ?? session.startedAt
        let isExpired = now().timeIntervalSince(lastActivityAt) > sessionExpirationInterval

        return mapper.mapActiveSession(
            session,
            programTitle: program.title,
            workoutDayTitle: day.title,
            completionPercentage: completion,
            isExpired: isExpired
        )
    }

    private nonisolated static func isMoreRecent(
        _ lhs: WorkoutSession,
        _ rhs: WorkoutSession
    ) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt
        return lhsDate == rhsDate ? lhs.startedAt > rhs.startedAt : lhsDate > rhsDate
    }
}
