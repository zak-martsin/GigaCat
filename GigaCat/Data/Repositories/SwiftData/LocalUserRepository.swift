//
//  LocalUserRepository.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//

import Foundation
import SwiftData

struct LocalUserRepository: UserRepository {
    private let context: ModelContext
    private let currentUserIDProvider: any CurrentUserIDProviding

    init(
        context: ModelContext,
        currentUserIDProvider: any CurrentUserIDProviding
    ) {
        self.context = context
        self.currentUserIDProvider = currentUserIDProvider
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
