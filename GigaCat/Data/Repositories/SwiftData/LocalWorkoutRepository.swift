//
//  LocalWorkoutRepository.swift
//  GigaCat
//
//  Created by OpenAI on 06/08/2026.
//

import Foundation
import SwiftData

struct LocalWorkoutRepository: WorkoutRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func activeSession(for userId: UUID) async throws -> WorkoutSession? {
        guard let entity = try findActiveSession(for: userId) else {
            return nil
        }

        return try WorkoutSessionMapper.toDomain(entity)
    }

    func startSession(
        userId: UUID,
        workoutDayId: UUID,
        startedAt: Date
    ) async throws -> WorkoutSession {
        guard try findUser(id: userId) != nil else {
            throw RepositoryError.userNotFound
        }

        guard try findWorkoutDay(id: workoutDayId) != nil else {
            throw RepositoryError.workoutDayNotFound
        }

        guard try findActiveSession(for: userId) == nil else {
            throw RepositoryError.activeSessionAlreadyExists
        }

        let session = try WorkoutSession(
            userId: userId,
            workoutDayId: workoutDayId,
            startedAt: startedAt
        )
        context.insert(WorkoutSessionMapper.toEntity(session))
        try context.save()

        return session
    }

    func completeSession(sessionId: UUID, completedAt: Date) async throws -> WorkoutSession {
        guard let entity = try findSession(id: sessionId) else {
            throw RepositoryError.workoutSessionNotFound
        }

        let session = try WorkoutSessionMapper.toDomain(entity)
        let completedSession = try session.markCompleted(at: completedAt)
        update(entity, from: completedSession)
        try context.save()

        return completedSession
    }

    func deleteSession(sessionId: UUID) async throws {
        guard let session = try findSession(id: sessionId) else {
            throw RepositoryError.workoutSessionNotFound
        }

        try deleteExerciseLogs(sessionId: sessionId)
        context.delete(session)
        try context.save()
    }

    func completeSessionAndSelectProgram(
        sessionId: UUID,
        completedAt: Date,
        userId: UUID,
        programId: UUID
    ) async throws -> User {
        guard let sessionEntity = try findSession(id: sessionId) else {
            throw RepositoryError.workoutSessionNotFound
        }

        let completedSession = try WorkoutSessionMapper.toDomain(sessionEntity)
            .markCompleted(at: completedAt)
        let (userEntity, updatedUser) = try userSelectingProgram(
            userId: userId,
            programId: programId
        )

        update(sessionEntity, from: completedSession)
        UserMapper.update(userEntity, from: updatedUser)
        try context.save()

        return updatedUser
    }

    func deleteSessionAndSelectProgram(
        sessionId: UUID,
        userId: UUID,
        programId: UUID
    ) async throws -> User {
        guard let sessionEntity = try findSession(id: sessionId) else {
            throw RepositoryError.workoutSessionNotFound
        }

        let (userEntity, updatedUser) = try userSelectingProgram(
            userId: userId,
            programId: programId
        )

        try deleteExerciseLogs(sessionId: sessionId)
        context.delete(sessionEntity)
        UserMapper.update(userEntity, from: updatedUser)
        try context.save()

        return updatedUser
    }

    func saveSet(_ input: WorkoutSetInput) async throws -> WorkoutSetSaveResult {
        guard try findUser(id: input.userId) != nil else {
            throw RepositoryError.userNotFound
        }

        guard try findWorkoutDay(id: input.workoutDayId) != nil else {
            throw RepositoryError.workoutDayNotFound
        }

        guard let dayExercise = try findWorkoutDayExercise(id: input.workoutDayExerciseId),
              dayExercise.workoutDayId == input.workoutDayId else {
            throw RepositoryError.exerciseNotFound
        }

        let existingSessionEntity = try findActiveSession(for: input.userId)
        if let existingSessionEntity,
           existingSessionEntity.workoutDayId != input.workoutDayId {
            throw RepositoryError.activeSessionWorkoutDayConflict
        }

        let didStartSession = existingSessionEntity == nil
        let session = try existingSessionEntity.map(WorkoutSessionMapper.toDomain) ?? WorkoutSession(
            userId: input.userId,
            workoutDayId: input.workoutDayId,
            startedAt: input.performedAt
        )
        let existingLogEntity = try findExerciseLog(
            sessionId: session.id,
            workoutDayExerciseId: input.workoutDayExerciseId,
            setNumber: input.setNumber
        )
        let log = try ExerciseLog(
            id: existingLogEntity?.id ?? UUID(),
            sessionId: session.id,
            workoutDayExerciseId: input.workoutDayExerciseId,
            weight: input.weight,
            reps: input.reps,
            setNumber: input.setNumber,
            performedAt: input.performedAt
        )

        if didStartSession {
            context.insert(WorkoutSessionMapper.toEntity(session))
        }

        if let existingLogEntity {
            update(existingLogEntity, from: log)
        } else {
            context.insert(ExerciseLogMapper.toEntity(log))
        }
        try context.save()

        return WorkoutSetSaveResult(
            session: session,
            log: log,
            didStartSession: didStartSession
        )
    }

    func fetchSessions(for userId: UUID) async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let entities = try context.fetch(descriptor)

        return try entities.map { try WorkoutSessionMapper.toDomain($0) }
    }

    func fetchExerciseLogs(sessionId: UUID) async throws -> [ExerciseLog] {
        let descriptor = FetchDescriptor<ExerciseLogEntity>(
            predicate: #Predicate {
                $0.sessionId == sessionId
            },
            sortBy: [
                SortDescriptor(\.workoutDayExerciseId),
                SortDescriptor(\.setNumber),
                SortDescriptor(\.performedAt)
            ]
        )
        let entities = try context.fetch(descriptor)

        return try entities.map { try ExerciseLogMapper.toDomain($0) }
    }

    func fetchLatestExerciseLog(
        userId: UUID,
        exerciseId: UUID
    ) async throws -> ExerciseLog? {
        let sessionIds = try fetchSessionIds(for: userId)
        let dayExerciseIds = try fetchWorkoutDayExerciseIds(for: exerciseId)

        guard !sessionIds.isEmpty, !dayExerciseIds.isEmpty else {
            return nil
        }

        var descriptor = FetchDescriptor<ExerciseLogEntity>(
            predicate: #Predicate {
                sessionIds.contains($0.sessionId) &&
                    dayExerciseIds.contains($0.workoutDayExerciseId)
            },
            sortBy: [
                SortDescriptor(\.performedAt, order: .reverse),
                SortDescriptor(\.setNumber, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1

        guard let entity = try context.fetch(descriptor).first else {
            return nil
        }
        return try ExerciseLogMapper.toDomain(entity)
    }
}

// MARK: - Fetch Helpers

private extension LocalWorkoutRepository {
    private func findActiveSession(for userId: UUID) throws -> WorkoutSessionEntity? {
        let inProgress = WorkoutSessionStatus.inProgress.rawValue
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId && $0.statusRawValue == inProgress
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findSession(id: UUID) throws -> WorkoutSessionEntity? {
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findUser(id: UUID) throws -> UserEntity? {
        var descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findProgram(id: UUID) throws -> WorkoutProgramEntity? {
        var descriptor = FetchDescriptor<WorkoutProgramEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findWorkoutDay(id: UUID) throws -> WorkoutDayEntity? {
        var descriptor = FetchDescriptor<WorkoutDayEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findWorkoutDayExercise(id: UUID) throws -> WorkoutDayExerciseEntity? {
        var descriptor = FetchDescriptor<WorkoutDayExerciseEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func findExerciseLog(
        sessionId: UUID,
        workoutDayExerciseId: UUID,
        setNumber: Int
    ) throws -> ExerciseLogEntity? {
        var descriptor = FetchDescriptor<ExerciseLogEntity>(
            predicate: #Predicate {
                $0.sessionId == sessionId &&
                    $0.workoutDayExerciseId == workoutDayExerciseId &&
                    $0.setNumber == setNumber
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func fetchSessionIds(for userId: UUID) throws -> [UUID] {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId
            }
        )

        return try context.fetch(descriptor).map(\.id)
    }

    private func fetchWorkoutDayExerciseIds(for exerciseId: UUID) throws -> [UUID] {
        let descriptor = FetchDescriptor<WorkoutDayExerciseEntity>(
            predicate: #Predicate {
                $0.exerciseId == exerciseId
            }
        )

        return try context.fetch(descriptor).map(\.id)
    }

    // MARK: - Mutation Helpers

    private func userSelectingProgram(
        userId: UUID,
        programId: UUID
    ) throws -> (UserEntity, User) {
        guard let userEntity = try findUser(id: userId) else {
            throw RepositoryError.userNotFound
        }

        guard try findProgram(id: programId) != nil else {
            throw RepositoryError.workoutProgramNotFound
        }

        let user = try UserMapper.toDomain(userEntity)
        return (userEntity, user.selectingProgram(programId))
    }

    private func deleteExerciseLogs(sessionId: UUID) throws {
        let descriptor = FetchDescriptor<ExerciseLogEntity>(
            predicate: #Predicate {
                $0.sessionId == sessionId
            }
        )

        try context.fetch(descriptor).forEach(context.delete)
    }

    private func update(_ entity: WorkoutSessionEntity, from session: WorkoutSession) {
        entity.userId = session.userId
        entity.workoutDayId = session.workoutDayId
        entity.statusRawValue = session.status.rawValue
        entity.startedAt = session.startedAt
        entity.completedAt = session.completedAt
    }

    private func update(_ entity: ExerciseLogEntity, from log: ExerciseLog) {
        entity.sessionId = log.sessionId
        entity.workoutDayExerciseId = log.workoutDayExerciseId
        entity.weight = log.weight
        entity.reps = log.reps
        entity.setNumber = log.setNumber
        entity.performedAt = log.performedAt
    }
}
