//
//  LocalUserRepository.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//

import Foundation
import SwiftData

@MainActor
struct LocalUserRepository: UserRepository {
    private let context: ModelContext
    private let currentUserIDProvider: any CurrentUserIDProviding
    private let outboxWriter: UserProfileOutboxWriter
    private let profileChanges: ProfileChangeSource

    init(
        context: ModelContext,
        currentUserIDProvider: any CurrentUserIDProviding,
        profileChanges: ProfileChangeSource = ProfileChangeSource()
    ) {
        self.context = context
        self.profileChanges = profileChanges
        self.currentUserIDProvider = currentUserIDProvider
        outboxWriter = UserProfileOutboxWriter(context: context)
    }

    func currentUser() async throws -> User? {
        guard let userID = await currentUserIDProvider.currentUserID() else {
            return nil
        }

        if let entity = try findUser(id: userID) {
            return UserMapper.toDomain(entity)
        }

        let user = User(id: userID)
        context.insert(UserMapper.toEntity(user))
        try context.save()
        return user
    }

    func user(id: UUID) async throws -> User? {
        guard let entity = try findUser(id: id) else {
            return nil
        }
        return UserMapper.toDomain(entity)
    }

    func save(_ user: User) async throws {
        if let entity = try findUser(id: user.id) {
            UserMapper.update(entity, from: user)
        } else {
            context.insert(UserMapper.toEntity(user))
        }
        try context.save()
    }

    func updateTrainingPreferences(for userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) async throws -> User {
        try LocalTrainingProfileWriter(context: context).update(userID: userID, goal: goal, level: level)
    }

    func profileSnapshot(for userID: UUID) async throws -> LocalProfileSnapshot {
        let entity = try findUser(id: userID)
        return LocalProfileSnapshot(
            userID: userID,
            user: entity.map(UserMapper.toDomain),
            revision: entity?.revision
        )
    }

    func applyFetchedProfile(
        _ user: User,
        ifUnchangedSince snapshot: LocalProfileSnapshot
    ) async throws -> Bool {
        guard user.id == snapshot.userID,
              await currentUserIDProvider.currentUserID() == user.id else { return false }

        // Keep the version/outbox check and the write in one actor-isolated operation.
        let entity = try findUser(id: user.id)
        let currentUser = entity.map(UserMapper.toDomain)
        let hasUnresolvedChange = try LocalSyncOutboxRepository(context: context)
            .hasUnresolvedProfileOperation(for: user.id)
        guard entity?.revision == snapshot.revision,
              currentUser == snapshot.user,
              !hasUnresolvedChange else {
            return false
        }

        let didChange = try LocalProfileApplication(context: context).apply(user, to: entity)
        if didChange { profileChanges.publish(userID: user.id) }
        return didChange
    }

    func discardFailedProfileChanges(applying user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) async throws -> Bool {
        guard user.id == snapshot.userID,
              await currentUserIDProvider.currentUserID() == user.id else { return false }
        let entity = try findUser(id: user.id)
        guard entity?.revision == snapshot.revision, entity.map(UserMapper.toDomain) == snapshot.user else { return false }
        let profileType = SyncAggregateType.userProfile.rawValue
        let userID = user.id
        let operations = try context.fetch(FetchDescriptor<SyncOperationEntity>(predicate: #Predicate {
            $0.userId == userID && $0.aggregateTypeRawValue == profileType
        }))
        guard !operations.isEmpty,
              operations.allSatisfy({ $0.statusRawValue == SyncOperationStatus.failed.rawValue }) else { return false }
        let didChange = try LocalProfileApplication(context: context).apply(user, to: entity, removing: operations)
        if didChange { profileChanges.publish(userID: user.id) }
        return didChange
    }

    func updateSelectedProgram(for userId: UUID, programId: UUID?) async throws -> User {
        guard let entity = try findUser(id: userId) else {
            throw RepositoryError.userNotFound
        }

        if let programId {
            guard try findProgram(id: programId) != nil else {
                throw RepositoryError.workoutProgramNotFound
            }
        }

        entity.selectedProgramId = programId
        entity.updatedAt = Date()
        entity.revision += 1
        try outboxWriter.enqueueProfileUpdate(for: entity)

        try context.save()

        return UserMapper.toDomain(entity)
    }

    private func findUser(id: UUID) throws -> UserEntity? {
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        return try context.fetch(descriptor).first
    }

    private func findProgram(id: UUID) throws -> WorkoutProgramEntity? {
        let descriptor = FetchDescriptor<WorkoutProgramEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )

        return try context.fetch(descriptor).first
    }
}
