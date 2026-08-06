//
//  LocalWorkoutProgramLibraryRepository.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//

import Foundation
import SwiftData

struct LocalWorkoutProgramLibraryRepository: WorkoutProgramLibraryRepository {

    private let context: ModelContext

    init (context: ModelContext) {
        self.context = context
    }

    func fetchSavedPrograms(for userId: UUID) async throws -> [WorkoutProgram] {
        guard try findUser(id: userId) != nil else {
             throw RepositoryError.userNotFound
        }

        let savedProgramDescriptor = FetchDescriptor<SavedWorkoutProgramEntity>(
            predicate:
                #Predicate {
                    $0.userId == userId
                },
            sortBy: [
                SortDescriptor(\.savedAt, order: .reverse)
            ]
        )

        let programIds = try context.fetch(savedProgramDescriptor)
            .map {$0.programId}

        guard !programIds.isEmpty else {
            return []
        }

        let descriptor = FetchDescriptor<WorkoutProgramEntity>(
            predicate:
                #Predicate {
                    programIds.contains($0.id)
                }
        )

        let entities = try context.fetch(descriptor)

        let entitiesById = Dictionary(
            uniqueKeysWithValues: entities.map { ($0.id, $0) }
        )

        return try programIds.map { id in
            guard let entity = entitiesById[id] else {
                throw RepositoryError.workoutProgramNotFound
            }
            return try WorkoutProgramMapper.toDomain(entity)
        }
    }

    func isProgramSaved(_ programId: UUID, for userId: UUID) async throws -> Bool {
        guard try findUser(id: userId) != nil else {
            throw  RepositoryError.userNotFound
        }

        var descriptor = FetchDescriptor<SavedWorkoutProgramEntity>(
            predicate:
                #Predicate {
                    $0.programId == programId && $0.userId == userId
                }
        )
        descriptor.fetchLimit = 1

        return try !context.fetch(descriptor).isEmpty
    }

    func saveProgram(_ programId: UUID, for userId: UUID) async throws {
        guard try findUser(id: userId) != nil else {
            throw  RepositoryError.userNotFound
        }

        guard try findProgram(id: programId) != nil else {
            throw RepositoryError.workoutProgramNotFound
        }

        guard try await !isProgramSaved(programId, for: userId) else { return }

        let savedProgram = SavedWorkoutProgram(
            userId: userId,
            programId: programId,
            savedAt: Date()
        )

        context.insert(SavedWorkoutProgramMapper.toEntity(savedProgram))
        try context.save()
    }

    func removeProgram(_ programId: UUID, for userId: UUID) async throws {

        guard try findUser(id: userId) != nil else {
            throw RepositoryError.userNotFound
        }

        let descriptor = FetchDescriptor<SavedWorkoutProgramEntity>(
                predicate: #Predicate {
                    $0.userId == userId &&
                    $0.programId == programId
                }
            )

            let savedPrograms = try context.fetch(descriptor)

            guard !savedPrograms.isEmpty else {
                return
            }

            for savedProgram in savedPrograms {
                context.delete(savedProgram)
            }

            try context.save()
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
