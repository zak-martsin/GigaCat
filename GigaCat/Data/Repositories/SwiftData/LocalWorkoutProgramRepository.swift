//
//  LocalWorkoutProgramRepository.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 06/08/2026.
//

import Foundation
import SwiftData

struct LocalWorkoutProgramRepository: WorkoutProgramRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchPrograms() async throws -> [WorkoutProgram] {
        let descriptor = FetchDescriptor<WorkoutProgramEntity>(
            sortBy: [SortDescriptor(\.title)]
        )
        let programs = try context.fetch(descriptor)

        return try programs.map { try WorkoutProgramMapper.toDomain($0) }
    }

    func fetchProgram(id: UUID) async throws -> WorkoutProgram? {

        guard let program = try findProgram(id: id) else {
            throw RepositoryError.workoutProgramNotFound
        }
        return try WorkoutProgramMapper.toDomain(program)
    }

    func fetchWorkoutDays(programId: UUID) async throws -> [WorkoutDay] {
        guard try findProgram(id: programId) != nil else {
            throw RepositoryError.workoutProgramNotFound
        }

        let descriptor = FetchDescriptor<WorkoutDayEntity>(
            predicate:
                #Predicate {
                    $0.programId == programId
                },
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let days = try context.fetch(descriptor)

        return try days.map { try WorkoutDayMapper.toDomain($0) }
    }

    func fetchWorkoutDay(id: UUID) async throws -> WorkoutDay? {
        var descriptor = FetchDescriptor<WorkoutDayEntity>(
            predicate:
                #Predicate {
                    $0.id == id
                }
        )
        descriptor.fetchLimit = 1

        guard let entity = try context.fetch(descriptor).first else {
            return nil
        }
        return try WorkoutDayMapper.toDomain(entity)
    }

    func fetchWorkoutDayExercises(workoutDayId: UUID) async throws -> [WorkoutDayExercise] {
        guard try findWorkoutDay(id: workoutDayId) != nil else {
            throw RepositoryError.workoutDayNotFound
        }

        let descriptor = FetchDescriptor<WorkoutDayExerciseEntity>(
            predicate: #Predicate {
                $0.workoutDayId == workoutDayId
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let entities = try context.fetch(descriptor)

        return try entities.map { try WorkoutDayExerciseMapper.toDomain($0) }
    }

    func fetchExercise(id: UUID) async throws -> Exercise? {
        var descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate {
                $0.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let entity = try context.fetch(descriptor).first else {
            return nil
        }
        return try ExerciseMapper.toDomain(entity)
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
}
