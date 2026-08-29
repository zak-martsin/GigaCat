//
//  SwiftDataMappers.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//

enum UserMapper {
    static func toDomain(_ entity: UserEntity) -> User {
        User(id: entity.id,
             selectedProgramId: entity.selectedProgramId,
             createdAt: entity.createdAt,
             updatedAt: entity.updatedAt
        )
    }

    static func toEntity(_ domain: User) -> UserEntity {
        UserEntity(id: domain.id,
                   selectedProgramId: domain.selectedProgramId,
                   createdAt: domain.createdAt,
                   updatedAt: domain.updatedAt
        )
    }

    static func update(_ entity: UserEntity, from domain: User) {
        entity.selectedProgramId = domain.selectedProgramId
        entity.createdAt = domain.createdAt
        entity.updatedAt = domain.updatedAt
    }
}

enum WorkoutSessionMapper {
    static func toDomain(_ entity: WorkoutSessionEntity) throws -> WorkoutSession {
        guard let status = WorkoutSessionStatus(rawValue: entity.statusRawValue) else {
            throw RepositoryError.invalidWorkoutSessionStatus(entity.statusRawValue)
        }

        return try WorkoutSession(id: entity.id,
                                  userId: entity.userId,
                                  workoutDayId: entity.workoutDayId,
                                  status: status,
                                  startedAt: entity.startedAt,
                                  completedAt: entity.completedAt
        )
    }

    static func toEntity(_ domain: WorkoutSession) -> WorkoutSessionEntity {
        WorkoutSessionEntity(id: domain.id,
                             userId: domain.userId,
                             workoutDayId: domain.workoutDayId,
                             statusRawValue: domain.status.rawValue,
                             startedAt: domain.startedAt,
                             completedAt: domain.completedAt)
    }
}

enum ExerciseLogMapper {
    static func toDomain(_ entity: ExerciseLogEntity) throws -> ExerciseLog {
        try ExerciseLog(id: entity.id,
                        sessionId: entity.sessionId,
                        workoutDayExerciseId: entity.workoutDayExerciseId,
                        weight: entity.weight,
                        reps: entity.reps,
                        setNumber: entity.setNumber,
                        performedAt: entity.performedAt)
    }

    static func toEntity(_ domain: ExerciseLog) -> ExerciseLogEntity {
        ExerciseLogEntity(id: domain.id,
                          sessionId: domain.sessionId,
                          workoutDayExerciseId: domain.workoutDayExerciseId,
                          weight: domain.weight,
                          reps: domain.reps,
                          setNumber: domain.setNumber,
                          performedAt: domain.performedAt)
    }
}

enum WorkoutProgramMapper {
    static func toDomain(_ entity: WorkoutProgramEntity) throws -> WorkoutProgram {
        try  WorkoutProgram(id: entity.id,
                            authorId: entity.authorId,
                            audience: entity.audience,
                            isActive: entity.isActive,
                            title: entity.title,
                            description: entity.programDescription,
                            tags: entity.tags)
    }

    static func toEntity(_ domain: WorkoutProgram) -> WorkoutProgramEntity {
        WorkoutProgramEntity(id: domain.id,
                             authorId: domain.authorId,
                             audience: domain.audience,
                             isActive: domain.isActive,
                             title: domain.title,
                             description: domain.description,
                             tags: domain.tags)
    }

    static func update(_ entity: WorkoutProgramEntity, from domain: WorkoutProgram) {
        entity.authorId = domain.authorId
        entity.audience = domain.audience
        entity.isActive = domain.isActive
        entity.title = domain.title
        entity.programDescription = domain.description
        entity.tags = domain.tags
    }
}

enum WorkoutDayExerciseMapper {
    static func toDomain(_ entity: WorkoutDayExerciseEntity) throws -> WorkoutDayExercise {
        try WorkoutDayExercise(id: entity.id,
                               workoutDayId: entity.workoutDayId,
                               exerciseId: entity.exerciseId,
                               targetSets: entity.targetSets,
                               targetReps: entity.targetReps,
                               orderIndex: entity.orderIndex)
    }

    static func toEntity(_ domain: WorkoutDayExercise) -> WorkoutDayExerciseEntity {
        WorkoutDayExerciseEntity(id: domain.id,
                                 workoutDayId: domain.workoutDayId,
                                 exerciseId: domain.exerciseId,
                                 targetSets: domain.targetSets,
                                 targetReps: domain.targetReps,
                                 orderIndex: domain.orderIndex)
    }

    static func update(
        _ entity: WorkoutDayExerciseEntity,
        from domain: WorkoutDayExercise
    ) {
        entity.workoutDayId = domain.workoutDayId
        entity.exerciseId = domain.exerciseId
        entity.targetSets = domain.targetSets
        entity.targetReps = domain.targetReps
        entity.orderIndex = domain.orderIndex
        entity.isActive = true
    }
}

enum WorkoutDayMapper {
    static func toDomain(_ entity: WorkoutDayEntity) throws -> WorkoutDay {
        try WorkoutDay(
            id: entity.id,
            programId: entity.programId,
            title: entity.title,
            orderIndex: entity.orderIndex)
    }

    static func toEntity(_ domain: WorkoutDay) -> WorkoutDayEntity {
        WorkoutDayEntity(
            id: domain.id,
            programId: domain.programId,
            title: domain.title,
            orderIndex: domain.orderIndex)
    }

    static func update(_ entity: WorkoutDayEntity, from domain: WorkoutDay) {
        entity.programId = domain.programId
        entity.title = domain.title
        entity.orderIndex = domain.orderIndex
        entity.isActive = true
    }
}

enum ExerciseMapper {
    static func toDomain(_ entity: ExerciseEntity) throws -> Exercise {
        try Exercise(
            id: entity.id,
            name: entity.name,
            muscleGroup: entity.muscleGroup)
    }

    static func toEntity(_ domain: Exercise) -> ExerciseEntity {
        ExerciseEntity(
            id: domain.id,
            name: domain.name,
            muscleGroup: domain.muscleGroup)
    }

    static func update(_ entity: ExerciseEntity, from domain: Exercise) {
        entity.name = domain.name
        entity.muscleGroup = domain.muscleGroup
    }
}
