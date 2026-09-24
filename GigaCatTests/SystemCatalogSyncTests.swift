import Foundation
import SwiftData
import Testing
@testable import GigaCat

struct SupabaseSystemCatalogRepositoryTests {
    @Test
    func rpcResponseDecodesAsOneSnapshot() throws {
        let identifiers = CatalogTestIdentifiers()
        let json = """
        {
          "programs": [{
            "id": "\(identifiers.programID)", "author_id": null,
            "target_audience": "men", "title": "Split", "description": "Three days",
            "tags": ["gym", "strength"], "is_active": true,
            "artwork_path": "\(identifiers.programID)/hero.jpg", "artwork_revision": 1,
            "workout_days": [{
              "id": "\(identifiers.dayID)", "program_id": "\(identifiers.programID)",
              "title": "Day 1", "order_index": 0,
              "workout_day_exercises": [{
                "id": "\(identifiers.dayExerciseID)",
                "workout_day_id": "\(identifiers.dayID)",
                "exercise_id": "\(identifiers.exerciseID)",
                "target_sets": 2, "target_reps": null, "order_index": 0
              }]
            }]
          }],
          "exercises": [{
            "id": "\(identifiers.exerciseID)", "name": "Bench press",
            "muscle_group": "chest"
          }]
        }
        """

        let snapshot = try JSONDecoder().decode(SystemCatalogSnapshotDTO.self, from: Data(json.utf8))

        #expect(snapshot.programs.first?.workoutDays.first?.dayExercises.first?.targetSets == 2)
        #expect(snapshot.programs.first?.artworkPath == "\(identifiers.programID)/hero.jpg")
        #expect(snapshot.programs.first?.artworkRevision == 1)
        #expect(snapshot.exercises.first?.id == identifiers.exerciseID)
    }

    @Test
    func malformedRpcResponseIsRejected() {
        let json = """
        {"programs":[],"exercises":[{"id":"not-a-uuid"}]}
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SystemCatalogSnapshotDTO.self, from: Data(json.utf8))
        }
    }

    @Test
    func nestedRowsBecomeOneDomainSnapshot() async throws {
        let identifiers = CatalogTestIdentifiers()
        let client = SupabaseSystemCatalogClientStub(
            snapshot: SystemCatalogSnapshotDTO(
                programs: [identifiers.programDTO],
                exercises: [identifiers.exerciseDTO]
            )
        )
        let repository = SupabaseSystemCatalogRepository(catalogClient: client)

        let snapshot = try await repository.fetchSystemCatalog()

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.entries.first?.program.audience == .men)
        #expect(snapshot.entries.first?.program.artwork?.path == "\(identifiers.programID)/hero.jpg")
        #expect(snapshot.entries.first?.program.artwork?.revision == 1)
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
        let artworkRevisionChanged = try store.apply(
            identifiers.snapshot(artworkRevision: 2)
        )
        let updatedCatalog = try await factory.defaultProgramCatalogRepository
            .fetchProgramCatalog()
        let days = try await factory.workoutProgramRepository.fetchWorkoutDays(
            programId: identifiers.programID
        )
        let storedDays = try stack.mainContext.fetch(FetchDescriptor<WorkoutDayEntity>())

        #expect(catalog.map(\.program.title) == ["Updated title"])
        #expect(firstApplyChangedCatalog)
        #expect(!secondApplyChangedCatalog)
        #expect(catalog.first?.program.artwork?.revision == 1)
        #expect(artworkRevisionChanged)
        #expect(updatedCatalog.first?.program.artwork?.revision == 2)
        #expect(
            updatedCatalog.first?.program.artwork?.path
                == "\(identifiers.programID)/hero.jpg"
        )
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
    let snapshot: SystemCatalogSnapshotDTO

    func catalogSnapshot() async throws -> SystemCatalogSnapshotDTO {
        snapshot
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
            artworkPath: "\(programID)/hero.jpg",
            artworkRevision: 1,
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

    func snapshot(artworkRevision: Int = 1) throws -> SystemCatalogSnapshot {
        SystemCatalogSnapshot(
            entries: [
                ProgramCatalogEntry(
                    program: try WorkoutProgram(
                        id: programID,
                        audience: .men,
                        title: "Updated title",
                        description: "Updated description",
                        tags: [.gym, .strength],
                        artwork: try ProgramArtwork(
                            path: "\(programID)/hero.jpg",
                            revision: artworkRevision
                        )
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
