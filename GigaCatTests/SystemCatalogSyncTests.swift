import Foundation
import SwiftData
import Testing
@testable import GigaCat

struct SupabaseSystemCatalogRepositoryTests {
    @Test
    func nestedRowsBecomeOneDomainSnapshot() async throws {
        let identifiers = CatalogTestIdentifiers()
        let client = SupabaseSystemCatalogClientStub(
            programRows: [identifiers.programDTO],
            exerciseRows: [identifiers.exerciseDTO]
        )
        let repository = SupabaseSystemCatalogRepository(catalogClient: client)

        let snapshot = try await repository.fetchSystemCatalog()

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.entries.first?.program.audience == .men)
        #expect(snapshot.workoutDays.map(\.id) == [identifiers.dayID])
        #expect(snapshot.dayExercises.map(\.id) == [identifiers.dayExerciseID])
        #expect(snapshot.dayExercises.first?.targetSets == 2)
        #expect(snapshot.dayExercises.first?.targetReps == nil)
        #expect(snapshot.exercises.map(\.id) == [identifiers.exerciseID])
    }
}

@MainActor
struct SystemCatalogSyncServiceTests {
    @Test
    func emptyResponseDoesNotReplaceLocalCatalog() async {
        let localStore = SystemCatalogLocalStoreSpy()
        let service = SystemCatalogSyncService(
            remoteRepository: SystemCatalogRemoteRepositoryStub(
                snapshot: SystemCatalogSnapshot(
                    entries: [],
                    workoutDays: [],
                    dayExercises: [],
                    exercises: []
                )
            ),
            localStore: localStore
        )
        var receivedError: SystemCatalogSyncError?

        do {
            _ = try await service.refreshSystemCatalog()
        } catch {
            receivedError = error as? SystemCatalogSyncError
        }

        #expect(receivedError == .emptyCatalog)
        #expect(localStore.applyCount == 0)
    }

    @Test
    func incompleteSnapshotDoesNotReplaceLocalCatalog() async throws {
        let identifiers = CatalogTestIdentifiers()
        let validSnapshot = try identifiers.snapshot()
        let localStore = SystemCatalogLocalStoreSpy()
        let service = SystemCatalogSyncService(
            remoteRepository: SystemCatalogRemoteRepositoryStub(
                snapshot: SystemCatalogSnapshot(
                    entries: validSnapshot.entries,
                    workoutDays: validSnapshot.workoutDays,
                    dayExercises: [],
                    exercises: validSnapshot.exercises
                )
            ),
            localStore: localStore
        )

        await #expect(throws: SystemCatalogSyncError.invalidCatalog) {
            _ = try await service.refreshSystemCatalog()
        }
        #expect(localStore.applyCount == 0)
    }
}

@MainActor
struct LocalSystemCatalogStoreTests {
    @Test
    func applyingSnapshotUpsertsCatalogAndHidesRemovedSystemRecords() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let identifiers = CatalogTestIdentifiers()
        let staleDayID = UUID()
        let personalProgram = try WorkoutProgram(
            authorId: UUID(),
            title: "Personal",
            description: "User-owned program"
        )
        let existingProgram = try WorkoutProgram(
            id: identifiers.programID,
            title: "Old title",
            description: "Old description"
        )
        let staleDay = try WorkoutDay(
            id: staleDayID,
            programId: identifiers.programID,
            title: "Removed day",
            orderIndex: 1
        )

        stack.mainContext.insert(WorkoutProgramMapper.toEntity(existingProgram))
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(personalProgram))
        stack.mainContext.insert(WorkoutDayMapper.toEntity(staleDay))
        try stack.mainContext.save()

        let store = LocalSystemCatalogStore(context: stack.mainContext)
        let snapshot = try identifiers.snapshot()

        let firstApplyChangedCatalog = try store.apply(snapshot)
        let secondApplyChangedCatalog = try store.apply(snapshot)

        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext()
        )
        let catalog = try await factory.defaultProgramCatalogRepository.fetchProgramCatalog()
        let days = try await factory.workoutProgramRepository.fetchWorkoutDays(
            programId: identifiers.programID
        )
        let storedDays = try stack.mainContext.fetch(FetchDescriptor<WorkoutDayEntity>())

        #expect(catalog.map(\.program.title) == ["Updated title"])
        #expect(firstApplyChangedCatalog)
        #expect(!secondApplyChangedCatalog)
        #expect(!catalog.map(\.id).contains(personalProgram.id))
        #expect(days.map(\.id) == [identifiers.dayID])
        #expect(storedDays.first { $0.id == staleDayID }?.isActive == false)
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<WorkoutProgramEntity>()) == 2
        )
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<WorkoutDayExerciseEntity>()) == 1
        )
    }
}

private struct SupabaseSystemCatalogClientStub: SupabaseSystemCatalogClient {
    let programRows: [WorkoutProgramCatalogDTO]
    let exerciseRows: [ExerciseCatalogDTO]

    func systemPrograms() async throws -> [WorkoutProgramCatalogDTO] {
        programRows
    }

    func exercises() async throws -> [ExerciseCatalogDTO] {
        exerciseRows
    }
}

private struct SystemCatalogRemoteRepositoryStub: SystemCatalogRemoteRepository {
    let snapshot: SystemCatalogSnapshot

    func fetchSystemCatalog() async throws -> SystemCatalogSnapshot {
        snapshot
    }
}

@MainActor
private final class SystemCatalogLocalStoreSpy: SystemCatalogLocalStore {
    private(set) var applyCount = 0

    func apply(_ snapshot: SystemCatalogSnapshot) throws -> Bool {
        applyCount += 1
        return true
    }
}

private struct CatalogTestIdentifiers {
    let programID = UUID()
    let dayID = UUID()
    let exerciseID = UUID()
    let dayExerciseID = UUID()

    var programDTO: WorkoutProgramCatalogDTO {
        WorkoutProgramCatalogDTO(
            id: programID,
            authorID: nil,
            targetAudience: .men,
            title: "Updated title",
            description: "Updated description",
            tags: [.gym, .strength],
            isActive: true,
            workoutDays: [
                WorkoutDayCatalogDTO(
                    id: dayID,
                    programID: programID,
                    title: "Day 1",
                    orderIndex: 0,
                    dayExercises: [
                        WorkoutDayExerciseCatalogDTO(
                            id: dayExerciseID,
                            workoutDayID: dayID,
                            exerciseID: exerciseID,
                            targetSets: 2,
                            targetReps: nil,
                            orderIndex: 0
                        )
                    ]
                )
            ]
        )
    }

    var exerciseDTO: ExerciseCatalogDTO {
        ExerciseCatalogDTO(
            id: exerciseID,
            name: "Bench press",
            muscleGroup: .chest
        )
    }

    func snapshot() throws -> SystemCatalogSnapshot {
        SystemCatalogSnapshot(
            entries: [
                ProgramCatalogEntry(
                    program: try WorkoutProgram(
                        id: programID,
                        audience: .men,
                        title: "Updated title",
                        description: "Updated description",
                        tags: [.gym, .strength]
                    )
                )
            ],
            workoutDays: [
                try WorkoutDay(
                    id: dayID,
                    programId: programID,
                    title: "Day 1",
                    orderIndex: 0
                )
            ],
            dayExercises: [
                try WorkoutDayExercise(
                    id: dayExerciseID,
                    workoutDayId: dayID,
                    exerciseId: exerciseID,
                    orderIndex: 0
                )
            ],
            exercises: [
                try Exercise(
                    id: exerciseID,
                    name: "Bench press",
                    muscleGroup: .chest
                )
            ]
        )
    }
}
