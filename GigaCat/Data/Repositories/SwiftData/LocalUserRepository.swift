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
    private let store: MockDataStore

    init(context: ModelContext, store: MockDataStore) {
        self.context = context
        self.store = store
    }

    // TODO: Replace MockDataStore with authenticated user lookup once authentication is implemented.
    func currentUser() async throws -> User? {
        await store.currentUser()
    }

    func user(appleUserId: String) async throws -> User? {
        let descriptor = FetchDescriptor<UserEntity>(predicate: #Predicate{ $0.appleUserId == appleUserId})
        guard let entity = try context.fetch(descriptor).first else {
            return nil
        }
        return try UserMapper.toDomain(entity)
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

        return try UserMapper.toDomain(entity)
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
