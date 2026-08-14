import SwiftData

/// Inserts missing catalog records without creating demo user-owned data.
@MainActor
struct SwiftDataBootstrapService {
    private let context: ModelContext
    private let catalog: WorkoutCatalogSeed

    init(context: ModelContext, catalog: WorkoutCatalogSeed) {
        self.context = context
        self.catalog = catalog
    }

    /// Adds only records whose stable identifiers are not already present.
    @discardableResult
    func bootstrapIfNeeded() throws -> Bool {
        var didInsert = false

        if try insertMissingExercises() { didInsert = true }
        if try insertMissingPrograms() { didInsert = true }
        if try insertMissingMetadata() { didInsert = true }
        if try insertMissingWorkoutDays() { didInsert = true }
        if try insertMissingDayExercises() { didInsert = true }

        if didInsert {
            try context.save()
        }

        return didInsert
    }
}

private extension SwiftDataBootstrapService {
    func insertMissingExercises() throws -> Bool {
        let existingIDs = Set(
            try context.fetch(FetchDescriptor<ExerciseEntity>()).map(\.id)
        )
        let missing = catalog.exercises.filter { !existingIDs.contains($0.id) }
        missing.forEach { context.insert(ExerciseMapper.toEntity($0)) }
        return !missing.isEmpty
    }

    func insertMissingPrograms() throws -> Bool {
        let existingIDs = Set(
            try context.fetch(FetchDescriptor<WorkoutProgramEntity>()).map(\.id)
        )
        let missing = catalog.programs.filter { !existingIDs.contains($0.id) }
        missing.forEach { context.insert(WorkoutProgramMapper.toEntity($0)) }
        return !missing.isEmpty
    }

    func insertMissingMetadata() throws -> Bool {
        let existingIDs = Set(
            try context.fetch(FetchDescriptor<ProgramCatalogMetadataEntity>()).map(\.programId)
        )
        let missing = catalog.metadataByProgramID.filter {
            !existingIDs.contains($0.key)
        }

        missing.forEach { programID, metadata in
            context.insert(
                ProgramCatalogMetadataEntity(
                    programId: programID,
                    isRecommended: metadata.isRecommended,
                    isPopular: metadata.isPopular,
                    rateScore: metadata.rateScore
                )
            )
        }
        return !missing.isEmpty
    }

    func insertMissingWorkoutDays() throws -> Bool {
        let existingIDs = Set(
            try context.fetch(FetchDescriptor<WorkoutDayEntity>()).map(\.id)
        )
        let missing = catalog.workoutDays.filter { !existingIDs.contains($0.id) }
        missing.forEach { context.insert(WorkoutDayMapper.toEntity($0)) }
        return !missing.isEmpty
    }

    func insertMissingDayExercises() throws -> Bool {
        let existingIDs = Set(
            try context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>()).map(\.id)
        )
        let missing = catalog.dayExercises.filter { !existingIDs.contains($0.id) }
        missing.forEach { context.insert(WorkoutDayExerciseMapper.toEntity($0)) }
        return !missing.isEmpty
    }
}
