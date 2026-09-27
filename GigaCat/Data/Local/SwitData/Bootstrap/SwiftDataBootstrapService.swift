import SwiftData

/// Restores missing bundled catalog data without creating demo user-owned data.
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
        var didChange = false

        if try insertMissingExercises() { didChange = true }
        if try insertMissingPrograms() { didChange = true }
        if try backfillMissingProgramArtwork() { didChange = true }
        if try insertMissingWorkoutDays() { didChange = true }
        if try insertMissingDayExercises() { didChange = true }

        if didChange {
            try context.save()
        }

        return didChange
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

    /// Repairs artwork metadata added after a bundled system program was first stored.
    func backfillMissingProgramArtwork() throws -> Bool {
        let bundledProgramsByID = Dictionary(
            uniqueKeysWithValues: catalog.programs.map { ($0.id, $0) }
        )
        let entities = try context.fetch(FetchDescriptor<WorkoutProgramEntity>())
        var didChange = false

        for entity in entities {
            guard entity.authorId == nil,
                  entity.artworkPath == nil || entity.artworkRevision <= 0,
                  let artwork = bundledProgramsByID[entity.id]?.artwork else {
                continue
            }

            entity.artworkPath = artwork.path
            entity.artworkRevision = artwork.revision
            didChange = true
        }

        return didChange
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
