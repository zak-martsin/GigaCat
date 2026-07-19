import Foundation

struct ProgramCatalogMetadata: Equatable, Sendable {
    let isRecommended: Bool
    let isPopular: Bool
    let rateScore: Double?

    init(
        isRecommended: Bool = false,
        isPopular: Bool = false,
        rateScore: Double? = nil
    ) {
        self.isRecommended = isRecommended
        self.isPopular = isPopular
        self.rateScore = rateScore
    }
}

/// Shared in-memory source used by mock repositories to simulate a consistent offline-first data layer.
actor MockDataStore {
    private(set) var usersByID: [UUID: User]
    private(set) var programsByID: [UUID: WorkoutProgram]
    private(set) var programCatalogMetadataByProgramIDStorage: [UUID: ProgramCatalogMetadata]
    private(set) var workoutDaysByID: [UUID: WorkoutDay]
    private(set) var dayExercisesByID: [UUID: WorkoutDayExercise]
    private(set) var exercisesByID: [UUID: Exercise]
    private(set) var sessionsByID: [UUID: WorkoutSession]
    private(set) var exerciseLogsByID: [UUID: ExerciseLog]
    private(set) var currentUserID: UUID?

    init(
        users: [User] = [],
        programs: [WorkoutProgram] = [],
        programCatalogMetadataByProgramID: [UUID: ProgramCatalogMetadata] = [:],
        workoutDays: [WorkoutDay] = [],
        dayExercises: [WorkoutDayExercise] = [],
        exercises: [Exercise] = [],
        sessions: [WorkoutSession] = [],
        exerciseLogs: [ExerciseLog] = [],
        currentUserID: UUID? = nil
    ) {
        self.usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        self.programsByID = Dictionary(uniqueKeysWithValues: programs.map { ($0.id, $0) })
        self.programCatalogMetadataByProgramIDStorage = programCatalogMetadataByProgramID
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

    func user(appleUserId: String) -> User? {
        usersByID.values.first { $0.appleUserId == appleUserId }
    }

    func saveUser(_ user: User) {
        usersByID[user.id] = user
        if currentUserID == nil {
            currentUserID = user.id
        }
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
        return updatedUser
    }

    // MARK: - Programs

    func programs() -> [WorkoutProgram] {
        programsByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func program(id: UUID) -> WorkoutProgram? {
        programsByID[id]
    }

    func programCatalogMetadataByProgramID() -> [UUID: ProgramCatalogMetadata] {
        programCatalogMetadataByProgramIDStorage
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

    /// Starts a session only when the user exists, the workout day exists, and there is no active session yet.
    func startSession(userId: UUID, workoutDayId: UUID, startedAt: Date) throws -> WorkoutSession {
        guard usersByID[userId] != nil else {
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
            startedAt: startedAt
        )
        sessionsByID[session.id] = session
        return session
    }

    func completeSession(sessionId: UUID, completedAt: Date) throws -> WorkoutSession {
        guard let session = sessionsByID[sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }

        let completedSession = try session.markCompleted(at: completedAt)
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

        let completedSession = try session.markCompleted(at: completedAt)
        let updatedUser = try updatedUserSelectingProgram(for: userId, programId: programId)

        sessionsByID[sessionId] = completedSession
        usersByID[userId] = updatedUser
        return updatedUser
    }

    func deleteSession(sessionId: UUID) throws {
        guard sessionsByID[sessionId] != nil else {
            throw RepositoryError.workoutSessionNotFound
        }

        sessionsByID.removeValue(forKey: sessionId)
        exerciseLogsByID = exerciseLogsByID.filter { $0.value.sessionId != sessionId }
    }

    func deleteSessionAndSelectProgram(
        sessionId: UUID,
        userId: UUID,
        programId: UUID
    ) throws -> User {
        guard sessionsByID[sessionId] != nil else {
            throw RepositoryError.workoutSessionNotFound
        }

        let updatedUser = try updatedUserSelectingProgram(for: userId, programId: programId)

        sessionsByID.removeValue(forKey: sessionId)
        exerciseLogsByID = exerciseLogsByID.filter { $0.value.sessionId != sessionId }
        usersByID[userId] = updatedUser
        return updatedUser
    }

    func saveExerciseLog(_ log: ExerciseLog) throws -> ExerciseLog {
        guard let session = sessionsByID[log.sessionId] else {
            throw RepositoryError.workoutSessionNotFound
        }

        guard let workoutDayExercise = dayExercisesByID[log.workoutDayExerciseId] else {
            throw RepositoryError.exerciseNotFound
        }

        guard workoutDayExercise.workoutDayId == session.workoutDayId else {
            throw RepositoryError.exerciseNotFound
        }

        guard session.status == .inProgress else {
            throw RepositoryError.workoutSessionNotActive
        }

        if let existingLogID = exerciseLogsByID.values.first(where: {
            $0.sessionId == log.sessionId &&
                $0.workoutDayExerciseId == log.workoutDayExerciseId &&
                $0.setNumber == log.setNumber
        })?.id {
            exerciseLogsByID.removeValue(forKey: existingLogID)
        }

        exerciseLogsByID[log.id] = log
        return log
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

    /// Filters logs to one user and one exercise, then orders from newest performance backward.
    func recentExerciseLogs(userId: UUID, exerciseId: UUID, limit: Int) -> [ExerciseLog] {
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
            .prefix(limit)
            .map { $0 }
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
