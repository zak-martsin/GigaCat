import Foundation

/// Loads completed workout history and resolves the referenced workout metadata.
protocol ProgressHistoryServicing {
    func loadHistory() async throws -> ProgressHistoryContext
}

enum ProgressHistoryError: Error, Equatable {
    case currentUserNotFound
    case workoutProgramNotFound
    case workoutDayNotFound
    case workoutDayExerciseNotFound
    case exerciseNotFound
}

struct ProgressHistoryService: ProgressHistoryServicing {
    private let userRepository: UserRepository
    private let workoutRepository: WorkoutRepository
    private let workoutProgramRepository: WorkoutProgramRepository

    init(
        userRepository: UserRepository,
        workoutRepository: WorkoutRepository,
        workoutProgramRepository: WorkoutProgramRepository
    ) {
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        self.workoutProgramRepository = workoutProgramRepository
    }

    func loadHistory() async throws -> ProgressHistoryContext {
        guard let user = try await userRepository.currentUser() else {
            throw ProgressHistoryError.currentUserNotFound
        }

        let sessions = try await workoutRepository.fetchSessions(for: user.id)
            .filter { $0.status == .completed }
            .sorted(by: Self.isMoreRecent)
        var sessionHistories: [ProgressSessionHistory] = []

        for session in sessions {
            sessionHistories.append(try await makeSessionHistory(for: session))
        }

        return ProgressHistoryContext(
            userID: user.id,
            sessions: sessionHistories
        )
    }

    private func makeSessionHistory(
        for session: WorkoutSession
    ) async throws -> ProgressSessionHistory {
        guard let workoutDay = try await workoutProgramRepository.fetchWorkoutDay(
            id: session.workoutDayId
        ) else {
            throw ProgressHistoryError.workoutDayNotFound
        }

        guard let workoutProgram = try await workoutProgramRepository.fetchProgram(
            id: workoutDay.programId
        ) else {
            throw ProgressHistoryError.workoutProgramNotFound
        }

        let dayExercises = try await workoutProgramRepository.fetchWorkoutDayExercises(
            workoutDayId: workoutDay.id
        )
        let logs = try await workoutRepository.fetchExerciseLogs(sessionId: session.id)
        let logsByDayExerciseID = Dictionary(grouping: logs, by: \.workoutDayExerciseId)
        var exerciseHistories: [ProgressExerciseHistory] = []

        for dayExercise in dayExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exerciseLogs = logsByDayExerciseID[dayExercise.id],
                  !exerciseLogs.isEmpty else {
                continue
            }

            guard let exercise = try await workoutProgramRepository.fetchExercise(
                id: dayExercise.exerciseId
            ) else {
                throw ProgressHistoryError.exerciseNotFound
            }

            exerciseHistories.append(
                ProgressExerciseHistory(
                    dayExercise: dayExercise,
                    exercise: exercise,
                    logs: exerciseLogs.sorted(by: Self.isEarlierSet)
                )
            )
        }

        let knownDayExerciseIDs = Set(dayExercises.map(\.id))
        guard logs.allSatisfy({ knownDayExerciseIDs.contains($0.workoutDayExerciseId) }) else {
            throw ProgressHistoryError.workoutDayExerciseNotFound
        }

        return ProgressSessionHistory(
            session: session,
            workoutDay: workoutDay,
            programTitle: workoutProgram.title,
            exercises: exerciseHistories
        )
    }

    private static func isMoreRecent(
        _ lhs: WorkoutSession,
        _ rhs: WorkoutSession
    ) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt

        if lhsDate == rhsDate {
            return lhs.startedAt > rhs.startedAt
        }

        return lhsDate > rhsDate
    }

    private static func isEarlierSet(
        _ lhs: ExerciseLog,
        _ rhs: ExerciseLog
    ) -> Bool {
        if lhs.setNumber == rhs.setNumber {
            return lhs.performedAt < rhs.performedAt
        }

        return lhs.setNumber < rhs.setNumber
    }
}
