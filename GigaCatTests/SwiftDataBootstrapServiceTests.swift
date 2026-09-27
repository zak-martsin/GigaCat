import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct SwiftDataBootstrapServiceTests {

    @Test
    func bootstrapAddsCatalogOnceWithoutUserOwnedData() throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let catalog = try BundledDefaultCatalog.load()
        let service = SwiftDataBootstrapService(
            context: stack.mainContext,
            catalog: catalog
        )

        let firstBootstrapInsertedData = try service.bootstrapIfNeeded()
        let secondBootstrapInsertedData = try service.bootstrapIfNeeded()

        #expect(firstBootstrapInsertedData)
        #expect(!secondBootstrapInsertedData)
        try expectCatalogCounts(in: stack.mainContext, match: catalog)

        #expect(try stack.mainContext.fetchCount(FetchDescriptor<UserEntity>()) == 0)
        #expect(try stack.mainContext.fetchCount(FetchDescriptor<WorkoutSessionEntity>()) == 0)
        #expect(try stack.mainContext.fetchCount(FetchDescriptor<ExerciseLogEntity>()) == 0)
    }

    @Test
    func bootstrapCompletesPartiallyStoredCatalogWithoutReplacingExistingRecords() throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let catalog = try BundledDefaultCatalog.load()
        let existingProgram = WorkoutProgramMapper.toEntity(try #require(catalog.programs.first))
        let existingExercise = ExerciseMapper.toEntity(try #require(catalog.exercises.first))
        existingProgram.title = "Locally edited title"
        existingProgram.artworkPath = nil
        existingProgram.artworkRevision = 0

        stack.mainContext.insert(existingProgram)
        stack.mainContext.insert(existingExercise)
        try stack.mainContext.save()

        let service = SwiftDataBootstrapService(
            context: stack.mainContext,
            catalog: catalog
        )
        let didInsert = try service.bootstrapIfNeeded()

        #expect(didInsert)
        try expectCatalogCounts(in: stack.mainContext, match: catalog)

        let programs = try stack.mainContext.fetch(FetchDescriptor<WorkoutProgramEntity>())
        let storedProgram = try #require(programs.first { $0.id == existingProgram.id })
        let bundledArtwork = try #require(catalog.programs.first?.artwork)
        #expect(storedProgram.title == "Locally edited title")
        #expect(storedProgram.artworkPath == bundledArtwork.path)
        #expect(storedProgram.artworkRevision == bundledArtwork.revision)
    }
}

@MainActor
private func expectCatalogCounts(
    in context: ModelContext,
    match catalog: WorkoutCatalogSeed
) throws {
    #expect(try context.fetchCount(FetchDescriptor<WorkoutProgramEntity>()) == catalog.programs.count)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutDayEntity>()) == catalog.workoutDays.count)
    #expect(
        try context.fetchCount(FetchDescriptor<WorkoutDayExerciseEntity>())
            == catalog.dayExercises.count
    )
    #expect(try context.fetchCount(FetchDescriptor<ExerciseEntity>()) == catalog.exercises.count)
}
