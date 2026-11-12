import Foundation

/// Shared in-memory source used by mock repositories to simulate a consistent offline-first data layer.
actor MockDataStore {
    // MARK: - Stored State

    private(set) var usersByID: [UUID: User]
    private var userRevisionsByID: [UUID: Int]
    private(set) var programsByID: [UUID: WorkoutProgram]
    private(set) var workoutDaysByID: [UUID: WorkoutDay]
    private(set) var dayExercisesByID: [UUID: WorkoutDayExercise]
    private(set) var exercisesByID: [UUID: Exercise]
    private(set) var sessionsByID: [UUID: WorkoutSession]
    private(set) var exerciseLogsByID: [UUID: ExerciseLog]
    private(set) var currentUserID: UUID?

    // MARK: - Initialization

    init(
        users: [User] = [],
        programs: [WorkoutProgram] = [],
        workoutDays: [WorkoutDay] = [],
        dayExercises: [WorkoutDayExercise] = [],
        exercises: [Exercise] = [],
        sessions: [WorkoutSession] = [],
        exerciseLogs: [ExerciseLog] = [],
        currentUserID: UUID? = nil
    ) {
        self.usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        self.userRevisionsByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, 0) })
        self.programsByID = Dictionary(uniqueKeysWithValues: programs.map { ($0.id, $0) })
        self.workoutDaysByID = Dictionary(uniqueKeysWithValues: workoutDays.map { ($0.id, $0) })
        self.dayExercisesByID = Dictionary(uniqueKeysWithValues: dayExercises.map { ($0.id, $0) })
        self.exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        self.sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        self.exerciseLogsByID = Dictionary(uniqueKeysWithValues: exerciseLogs.map { ($0.id, $0) })
        self.currentUserID = currentUserID
    }

    // MARK: - Users

    /// Returns the user that mock flows should treat as currently authenticated.
    func currentUser() -> User? {
        guard let currentUserID else { return nil }
        return usersByID[currentUserID]
    }

    func user(id: UUID) -> User? {
        usersByID[id]
    }

    func saveUser(_ user: User) {
        usersByID[user.id] = user
        userRevisionsByID[user.id, default: 0] += 1
        if currentUserID == nil {
            currentUserID = user.id
        }
    }

    func updateTrainingPreferences(for userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) throws -> User {
        guard let user = usersByID[userID] else { throw RepositoryError.userNotFound }
        guard user.goal != goal || user.level != level else { return user }
        let updated = user.updatingTraining(goal: goal, level: level)
        let active = sessionsByID.values.filter { $0.userId == userID && $0.isActive }
        let updatedSessions = try active.map { session in
            let resolved = try resolvedSession(session)
            return try resolved.replacingTargets(WorkoutTargetResolver().recalculated(
                resolved.exerciseTargets ?? [], user: updated
            ))
        }
        usersByID[userID] = updated
        userRevisionsByID[userID, default: 0] += 1
        for session in updatedSessions { sessionsByID[session.id] = session }
        return updated
    }

    func profileSnapshot(for userID: UUID) -> LocalProfileSnapshot {
        LocalProfileSnapshot(
            userID: userID,
            user: usersByID[userID],
            revision: userRevisionsByID[userID]
        )
    }

    /// Updates program selection only if both the user and referenced program exist in the store.
    func updateSelectedProgram(for userId: UUID, programId: UUID?) throws -> User {
        guard let user = usersByID[userId] else {
            throw RepositoryError.userNotFound
        }

        if let programId, programsByID[programId] == nil {
            throw RepositoryError.workoutProgramNotFound
        }

        let updatedUser = user.selectingProgram(programId)
        usersByID[userId] = updatedUser
        userRevisionsByID[userId, default: 0] += 1
        return updatedUser
    }

    // MARK: - Programs

    func programs() -> [WorkoutProgram] {
        programsByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func program(id: UUID) -> WorkoutProgram? {
        programsByID[id]
    }

    func workoutDays(programId: UUID) -> [WorkoutDay] {
        workoutDaysByID.values
            .filter { $0.programId == programId }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func workoutDay(id: UUID) -> WorkoutDay? {
        workoutDaysByID[id]
    }

    /// Returns planned exercises in workout order so UI can render the day deterministically.
    func workoutDayExercises(workoutDayId: UUID) -> [WorkoutDayExercise] {
        dayExercisesByID.values
            .filter { $0.workoutDayId == workoutDayId }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func exercise(id: UUID) -> Exercise? {
        exercisesByID[id]
    }

    // MARK: - Workouts

    func activeSession(for userId: UUID) -> WorkoutSession? {
        sessionsByID.values.first { $0.userId == userId && $0.status == .inProgress }
    }

    func reconcileActiveSession(for userID: UUID) throws -> WorkoutSession? {
        guard let session = activeSession(for: userID) else { return nil }
        let resolved = try resolvedSession(session)
        sessionsByID[session.id] = resolved
        return resolved
    }

    private func resolvedSession(_ session: WorkoutSession) throws -> WorkoutSession {
        guard session.isActive, session.exerciseTargets == nil else { return session }
        guard let user = usersByID[session.userId] else { throw RepositoryError.userNotFound }
        return try session.replacingTargets(initialTargets(workoutDayID: session.workoutDayId, user: user))
    }

    private func initialTargets(workoutDayID: UUID, user: User) -> [WorkoutExerciseTarget] {
        WorkoutTargetResolver().targets(
            exercises: dayExercisesByID.values.filter { $0.workoutDayId == workoutDayID }, user: user
        )
    }

    /// Starts a session only when the user exists, the workout day exists, and there is no active session yet.
    func startSession(userId: UUID, workoutDayId: UUID, startedAt: Date) throws -> WorkoutSession {
        guard let user = usersByID[userId] else {
            throw RepositoryError.userNotFound
        }

        guard workoutDaysByID[workoutDayId] != nil else {
            throw RepositoryError.workoutDayNotFound
        }

        guard activeSession(for: userId) == nil else {
            throw RepositoryError.activeSessionAlreadyExists
        }

        let session = try WorkoutSession(
            userId: userId,
            workoutDayId: workoutDayId,
            startedAt: startedAt,
            exerciseTargets: initialTargets(workoutDayID: workoutDayId, user: user)
        )
        sessionsByID[session.id] = session
        return session
    }

    func completeSession(
        sessionId: UUID,
        userId: UUID,
        completedAt: Date
    ) throws -> WorkoutSession {
        guard let session = sessionsByID[sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }
        try validateOwnership(of: session, userId: userId)

        let completedSession = try resolvedSession(session).markCompleted(at: completedAt)
        sessionsByID[sessionId] = completedSession
        return completedSession
    }

    func completeSessionAndSelectProgram(
        sessionId: UUID,
        completedAt: Date,
        userId: UUID,
        programId: UUID
    ) throws -> User {
        guard let session = sessionsByID[sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }
        try validateOwnership(of: session, userId: userId)

        let completedSession = try resolvedSession(session).markCompleted(at: completedAt)
        let updatedUser = try updatedUserSelectingProgram(for: userId, programId: programId)

        sessionsByID[sessionId] = completedSession
        usersByID[userId] = updatedUser
        return updatedUser
    }

    func deleteSession(sessionId: UUID, userId: UUID) throws {
        guard let session = sessionsByID[sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }
        try validateOwnership(of: session, userId: userId)

        sessionsByID.removeValue(forKey: sessionId)
        exerciseLogsByID = exerciseLogsByID.filter { $0.value.sessionId != sessionId }
    }

    func deleteSessionAndSelectProgram(
        sessionId: UUID,
        userId: UUID,
        programId: UUID
    ) throws -> User {
        guard let session = sessionsByID[sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }
        try validateOwnership(of: session, userId: userId)

        let updatedUser = try updatedUserSelectingProgram(for: userId, programId: programId)

        sessionsByID.removeValue(forKey: sessionId)
        exerciseLogsByID = exerciseLogsByID.filter { $0.value.sessionId != sessionId }
        usersByID[userId] = updatedUser
        return updatedUser
    }

    /// Creates the first session and saves its first set as one actor-isolated mutation.
    func saveSet(_ input: WorkoutSetInput) throws -> WorkoutSetSaveResult {
        guard let user = usersByID[input.userId] else {
            throw RepositoryError.userNotFound
        }

        guard workoutDaysByID[input.workoutDayId] != nil else {
            throw RepositoryError.workoutDayNotFound
        }

        guard let workoutDayExercise = dayExercisesByID[input.workoutDayExerciseId],
              workoutDayExercise.workoutDayId == input.workoutDayId else {
            throw RepositoryError.exerciseNotFound
        }

        let existingSession = activeSession(for: input.userId)
        if let existingSession,
           existingSession.workoutDayId != input.workoutDayId {
            throw RepositoryError.activeSessionWorkoutDayConflict
        }

        let session = try existingSession.map(resolvedSession) ?? WorkoutSession(
            userId: input.userId,
            workoutDayId: input.workoutDayId,
            startedAt: input.performedAt,
            exerciseTargets: initialTargets(workoutDayID: input.workoutDayId, user: user)
        )
        let existingLog = matchingExerciseLog(
            sessionId: session.id,
            workoutDayExerciseId: input.workoutDayExerciseId,
            setNumber: input.setNumber
        )
        let log = try ExerciseLog(
            id: existingLog?.id ?? UUID(),
            sessionId: session.id,
            workoutDayExerciseId: input.workoutDayExerciseId,
            weight: input.weight,
            reps: input.reps,
            setNumber: input.setNumber,
            performedAt: input.performedAt
        )

        sessionsByID[session.id] = session
        exerciseLogsByID[log.id] = log

        return WorkoutSetSaveResult(
            session: session,
            log: log,
            didStartSession: existingSession == nil
        )
    }

    // MARK: - Exercise History

    private func matchingExerciseLog(
        sessionId: UUID,
        workoutDayExerciseId: UUID,
        setNumber: Int
    ) -> ExerciseLog? {
        exerciseLogsByID.values.first {
            $0.sessionId == sessionId &&
                $0.workoutDayExerciseId == workoutDayExerciseId &&
                $0.setNumber == setNumber
        }
    }

    /// Returns newest sessions first to match history-style screens.
    func sessions(for userId: UUID) -> [WorkoutSession] {
        sessionsByID.values
            .filter { $0.userId == userId }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }

                return lhs.startedAt > rhs.startedAt
            }
    }

    /// Groups logs by session and then by set number so an exercise flow can reconstruct performed sets.
    func exerciseLogs(sessionId: UUID) -> [ExerciseLog] {
        exerciseLogsByID.values
            .filter { $0.sessionId == sessionId }
            .sorted { lhs, rhs in
                if lhs.workoutDayExerciseId == rhs.workoutDayExerciseId {
                    if lhs.setNumber == rhs.setNumber {
                        return lhs.performedAt < rhs.performedAt
                    }

                    return lhs.setNumber < rhs.setNumber
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// Returns the user's newest performance for a reusable exercise across every workout day.
    func latestExerciseLog(userId: UUID, exerciseId: UUID) -> ExerciseLog? {
        let userSessionIDs = Set(sessionsByID.values.filter { $0.userId == userId }.map(\.id))
        let matchingWorkoutDayExerciseIDs = Set(
            dayExercisesByID.values
                .filter { $0.exerciseId == exerciseId }
                .map(\.id)
        )

        return exerciseLogsByID.values
            .filter {
                matchingWorkoutDayExerciseIDs.contains($0.workoutDayExerciseId) &&
                    userSessionIDs.contains($0.sessionId)
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.performedAt
                let rhsDate = rhs.performedAt

                if lhsDate == rhsDate {
                    return lhs.setNumber > rhs.setNumber
                }

                return lhsDate > rhsDate
            }
            .first
    }

}

extension MockDataStore {
    func exerciseHistorySummary(
        userId: UUID,
        exerciseId: UUID
    ) -> ExerciseHistorySummary {
        let completedSessions = sessionsByID.values.filter {
            $0.userId == userId && $0.status == .completed
        }
        let sessionIDs = Set(completedSessions.map(\.id))
        let dayExerciseIDs = Set(
            dayExercisesByID.values
                .filter { $0.exerciseId == exerciseId }
                .map(\.id)
        )
        let logs = exerciseLogsByID.values.filter {
            sessionIDs.contains($0.sessionId) &&
                dayExerciseIDs.contains($0.workoutDayExerciseId)
        }

        return ExerciseHistorySummary(
            completedSessions: completedSessions,
            logs: logs
        )
    }

    // MARK: - Private Helpers

    private func validateOwnership(of session: WorkoutSession, userId: UUID) throws {
        guard session.userId == userId else {
            throw RepositoryError.workoutSessionOwnershipMismatch
        }
    }

    private func updatedUserSelectingProgram(for userId: UUID, programId: UUID) throws -> User {
        guard let user = usersByID[userId] else {
            throw RepositoryError.userNotFound
        }

        guard programsByID[programId] != nil else {
            throw RepositoryError.workoutProgramNotFound
        }

        return user.selectingProgram(programId)
    }
}

extension MockDataStore {
    func applyFetchedProfile(_ user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) throws -> Bool {
        guard user.id == snapshot.userID,
              userRevisionsByID[user.id] == snapshot.revision,
              usersByID[user.id] == snapshot.user,
              usersByID[user.id] != user else {
            return false
        }

        let previous = usersByID[user.id]
        let trainingChanged = previous?.goal != user.goal || previous?.level != user.level
        let sessions = trainingChanged ? sessionsByID.values.filter { $0.userId == user.id && $0.isActive } : []
        let updatedSessions = try sessions.map { session in
            let resolved = try resolvedSession(session)
            return try resolved.replacingTargets(WorkoutTargetResolver().recalculated(
                resolved.exerciseTargets ?? [], user: user
            ))
        }
        usersByID[user.id] = user
        for session in updatedSessions { sessionsByID[session.id] = session }
        return true
    }

}
