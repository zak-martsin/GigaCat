import SwiftData

/// Applies server catalog snapshots to SwiftData while preserving inactive records for history.
@MainActor
struct LocalSystemCatalogStore: SystemCatalogLocalStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func apply(_ snapshot: SystemCatalogSnapshot) throws -> Bool {
        do {
            var didChange = false

            if try applyPrograms(snapshot.entries) {
                didChange = true
            }
            if try applyExercises(snapshot.exercises) {
                didChange = true
            }
            if try applyWorkoutDays(snapshot.workoutDays) {
                didChange = true
            }
            if try applyDayExercises(snapshot.dayExercises) {
                didChange = true
            }

            if didChange {
                try context.save()
            }
            return didChange
        } catch {
            context.rollback()
            throw error
        }
    }
}

private extension LocalSystemCatalogStore {
    func applyPrograms(_ entries: [ProgramCatalogEntry]) throws -> Bool {
        let entities = try context.fetch(FetchDescriptor<WorkoutProgramEntity>())
        var entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        let incomingIDs = Set(entries.map(\.id))
        var didChange = false

        entities
            .filter { $0.authorId == nil && $0.isActive && !incomingIDs.contains($0.id) }
            .forEach {
                $0.isActive = false
                didChange = true
            }

        for entry in entries {
            if let entity = entitiesByID[entry.id] {
                if !entity.matches(entry.program) {
                    WorkoutProgramMapper.update(entity, from: entry.program)
                    didChange = true
                }
            } else {
                let entity = WorkoutProgramMapper.toEntity(entry.program)
                context.insert(entity)
                entitiesByID[entry.id] = entity
                didChange = true
            }
        }

        return didChange
    }

    func applyExercises(_ exercises: [Exercise]) throws -> Bool {
        let entities = try context.fetch(FetchDescriptor<ExerciseEntity>())
        var entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        var didChange = false

        for exercise in exercises {
            if let entity = entitiesByID[exercise.id] {
                if !entity.matches(exercise) {
                    ExerciseMapper.update(entity, from: exercise)
                    didChange = true
                }
            } else {
                let entity = ExerciseMapper.toEntity(exercise)
                context.insert(entity)
                entitiesByID[exercise.id] = entity
                didChange = true
            }
        }

        return didChange
    }

    func applyWorkoutDays(_ workoutDays: [WorkoutDay]) throws -> Bool {
        let programEntities = try context.fetch(FetchDescriptor<WorkoutProgramEntity>())
        let systemProgramIDs = Set(
            programEntities.filter { $0.authorId == nil }.map(\.id)
        )
        let entities = try context.fetch(FetchDescriptor<WorkoutDayEntity>())
        var entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        let incomingIDs = Set(workoutDays.map(\.id))
        var didChange = false

        entities
            .filter {
                systemProgramIDs.contains($0.programId)
                    && $0.isActive
                    && !incomingIDs.contains($0.id)
            }
            .forEach {
                $0.isActive = false
                didChange = true
            }

        for workoutDay in workoutDays {
            if let entity = entitiesByID[workoutDay.id] {
                if !entity.matches(workoutDay) {
                    WorkoutDayMapper.update(entity, from: workoutDay)
                    didChange = true
                }
            } else {
                let entity = WorkoutDayMapper.toEntity(workoutDay)
                context.insert(entity)
                entitiesByID[workoutDay.id] = entity
                didChange = true
            }
        }

        return didChange
    }

    func applyDayExercises(_ dayExercises: [WorkoutDayExercise]) throws -> Bool {
        let programEntities = try context.fetch(FetchDescriptor<WorkoutProgramEntity>())
        let systemProgramIDs = Set(
            programEntities.filter { $0.authorId == nil }.map(\.id)
        )
        let dayEntities = try context.fetch(FetchDescriptor<WorkoutDayEntity>())
        let systemWorkoutDayIDs = Set(
            dayEntities.filter { systemProgramIDs.contains($0.programId) }.map(\.id)
        )
        let entities = try context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>())
        var entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        let incomingIDs = Set(dayExercises.map(\.id))
        var didChange = false

        entities
            .filter {
                systemWorkoutDayIDs.contains($0.workoutDayId)
                    && $0.isActive
                    && !incomingIDs.contains($0.id)
            }
            .forEach {
                $0.isActive = false
                didChange = true
            }

        for dayExercise in dayExercises {
            if let entity = entitiesByID[dayExercise.id] {
                if !entity.matches(dayExercise) {
                    WorkoutDayExerciseMapper.update(entity, from: dayExercise)
                    didChange = true
                }
            } else {
                let entity = WorkoutDayExerciseMapper.toEntity(dayExercise)
                context.insert(entity)
                entitiesByID[dayExercise.id] = entity
                didChange = true
            }
        }

        return didChange
    }
}

private extension WorkoutProgramEntity {
    func matches(_ program: WorkoutProgram) -> Bool {
        authorId == program.authorId
            && audience == program.audience
            && isActive == program.isActive
            && title == program.title
            && programDescription == program.description
            && tags == program.tags
    }
}

private extension WorkoutDayEntity {
    func matches(_ day: WorkoutDay) -> Bool {
        programId == day.programId
            && title == day.title
            && orderIndex == day.orderIndex
            && isActive
    }
}

private extension WorkoutDayExerciseEntity {
    func matches(_ dayExercise: WorkoutDayExercise) -> Bool {
        workoutDayId == dayExercise.workoutDayId
            && exerciseId == dayExercise.exerciseId
            && targetSets == dayExercise.targetSets
            && targetReps == dayExercise.targetReps
            && orderIndex == dayExercise.orderIndex
            && isActive
    }
}

private extension ExerciseEntity {
    func matches(_ exercise: Exercise) -> Bool {
        name == exercise.name && muscleGroup == exercise.muscleGroup
    }
}
