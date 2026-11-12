import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct TrainingSessionMigrationTests {
    @Test
    func stageOneStoreMigratesCatalogWithoutInventingHistoricalTargets() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let legacy = try persistStageOneStore(at: url)
        let stack = try SwiftDataStack(storeURL: url)
        let factory = LocalRepositoryFactory(stack: stack, currentUserIDProvider: CurrentUserContext(userID: legacy.user.id))
        #expect(try await factory.userRepository.currentUser() == legacy.user)
        let catalog = try stack.mainContext.fetch(FetchDescriptor<WorkoutDayExerciseEntity>())
        #expect(catalog.filter { $0.id != legacy.otherAssignment.id }.allSatisfy { $0.targetSets == nil })
        #expect(catalog.first { $0.id == legacy.otherAssignment.id }?.targetSets == 7)
        let history = try #require(try await factory.workoutRepository.fetchSessions(for: legacy.user.id)
            .first { $0.id == legacy.completedID })
        #expect(history.exerciseTargets == nil)
        let active = try #require(try await factory.workoutRepository.activeSession(for: legacy.user.id))
        #expect(active.exerciseTargets?.count == legacy.exerciseCount)
        #expect(active.exerciseTargets?.allSatisfy { $0.targetSets == 4 && $0.programOverride == nil } == true)
        #expect(try await factory.workoutRepository.fetchExerciseLogs(sessionId: history.id) == [legacy.log])
        #expect(try factory.syncOutboxRepository.operationCount(for: legacy.user.id) == 1)
    }

    @Test
    func sessionRecommendationsSurviveDiskStoreRecreation() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let original = try await persistSession(at: url)
        let stack = try SwiftDataStack(storeURL: url)
        let repository = LocalWorkoutRepository(context: stack.mainContext)
        let restored = try #require(try await repository.activeSession(for: original.userId))
        #expect(restored == original)
        #expect(restored.exerciseTargets?.map(\.targetSets) == [4, 5, 4])
    }

    @Test(arguments: [false, true])
    func failedSaveRollsBackProfileTargetsRevisionAndOutbox(hasPendingOperation: Bool) async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let original = try await persistSession(at: url, queueProfile: hasPendingOperation)
        let configuration = ModelConfiguration("GigaCat", schema: SwiftDataStack.schema, url: url, allowsSave: false)
        let container = try ModelContainer(for: SwiftDataStack.schema, configurations: [configuration])
        let context = container.mainContext
        context.autosaveEnabled = false
        let user = try #require(context.fetch(FetchDescriptor<UserEntity>()).first)
        let before = UserMapper.toDomain(user)
        let revision = user.revision
        do {
            _ = try LocalTrainingProfileWriter(context: context).update(userID: before.id, goal: nil, level: nil)
            Issue.record("A read-only store unexpectedly accepted a profile write")
        } catch {
            #expect(UserMapper.toDomain(user) == before)
            #expect(user.revision == revision)
            let operations = try context.fetch(FetchDescriptor<SyncOperationEntity>())
            #expect(operations.count == (hasPendingOperation ? 1 : 0))
            if let operation = operations.first {
                #expect(operation.revision == revision)
                let payload = try JSONDecoder().decode(UserProfileSyncPayload.self, from: operation.payload)
                #expect(payload.personalization?.goal == before.goal)
                #expect(payload.personalization?.level == before.level)
            }
            #expect(try context.fetch(FetchDescriptor<WorkoutSessionEntity>()).first?.exerciseTargets == original.exerciseTargets)
        }
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func persistSession(at url: URL, queueProfile: Bool = false) async throws -> WorkoutSession {
        let fixture = try TrainingSessionFixture(storeURL: url)
        let session = try await fixture.start()
        if queueProfile {
            _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: fixture.day.programId)
        }
        return session
    }

    private func persistStageOneStore(at url: URL) throws -> LegacyTrainingSnapshot {
        let schema = Schema(versionedSchema: GigaCatSchemaV2.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("GigaCat", schema: schema, url: url)])
        let context = container.mainContext
        let catalog = try BundledDefaultCatalog.load()
        try SwiftDataBootstrapService(context: context, catalog: catalog).bootstrapIfNeeded()
        for assignment in try context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>()) { assignment.targetSets = 2 }
        let user = User(goal: .buildMuscle, level: .advanced, avatarPath: "account/avatar.png")
        context.insert(UserMapper.toEntity(user))
        let day = try #require(catalog.workoutDays.first)
        let assignment = try #require(catalog.dayExercises.first { $0.workoutDayId == day.id })
        let active = legacySession(user: user, day: day, completed: false)
        let history = legacySession(user: user, day: day, completed: true)
        context.insert(active)
        context.insert(history)
        let log = try ExerciseLog(
            sessionId: history.id, workoutDayExerciseId: assignment.id, weight: 50, reps: 8, setNumber: 4
        )
        context.insert(ExerciseLogMapper.toEntity(log))
        let otherAssignment = try WorkoutDayExercise(workoutDayId: UUID(), exerciseId: UUID(), targetSets: 7, orderIndex: 0)
        context.insert(WorkoutDayExerciseMapper.toEntity(otherAssignment))
        let userEntity = try #require(context.fetch(FetchDescriptor<UserEntity>()).first)
        try UserProfileOutboxWriter(context: context).enqueueProfileUpdate(for: userEntity)
        try context.save()
        return LegacyTrainingSnapshot(
            user: user, completedID: history.id, log: log, otherAssignment: otherAssignment,
            exerciseCount: catalog.dayExercises.filter { $0.workoutDayId == day.id }.count
        )
    }

    private func legacySession(user: User, day: WorkoutDay, completed: Bool) -> GigaCatSchemaV1.WorkoutSessionEntity {
        GigaCatSchemaV1.WorkoutSessionEntity(
            id: UUID(), userId: user.id, workoutDayId: day.id,
            statusRawValue: completed ? "completed" : "inProgress",
            startedAt: Date(timeIntervalSince1970: 1000),
            completedAt: completed ? Date(timeIntervalSince1970: 2000) : nil
        )
    }
}

private struct LegacyTrainingSnapshot {
    let user: User
    let completedID: UUID
    let log: ExerciseLog
    let otherAssignment: WorkoutDayExercise
    let exerciseCount: Int
}
