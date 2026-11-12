import Foundation
import SwiftData
import Testing
@testable import GigaCat

/// The pre-Profile-v1 user schema, kept frozen to exercise a real disk-store upgrade.
private enum LegacyProfileSchema {
    @Model
    final class UserEntity {
        @Attribute(.unique) var id: UUID
        var selectedProgramId: UUID?
        var createdAt: Date
        var updatedAt: Date
        var revision: Int = 0

        init(id: UUID, programID: UUID) {
            self.id = id
            selectedProgramId = programID
            createdAt = Date(timeIntervalSince1970: 1000)
            updatedAt = Date(timeIntervalSince1970: 2000)
            revision = 7
        }
    }
}

@MainActor
struct ProfileStorageCompatibilityTests {
    @Test
    func legacyDiskStoreUpgradesWithoutLosingProfileWorkoutOrOutbox() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let userID = UUID()
        let program = try WorkoutProgram(title: "Legacy", description: "Migration fixture")
        let day = try WorkoutDay(programId: program.id, title: "Day", orderIndex: 0)
        let exercise = try Exercise(name: "Bench", muscleGroup: .chest)
        let assignment = try WorkoutDayExercise(
            workoutDayId: day.id, exerciseId: exercise.id, targetSets: 2, orderIndex: 0
        )
        let session = try WorkoutSession(
            userId: userID, workoutDayId: day.id, status: .completed,
            startedAt: Date(timeIntervalSince1970: 1000), completedAt: Date(timeIntervalSince1970: 2000)
        )
        let log = try ExerciseLog(
            sessionId: session.id, workoutDayExerciseId: assignment.id,
            weight: 40, reps: 10, setNumber: 1
        )
        try persistLegacyStore(
            at: url, userID: userID, program: program, day: day,
            workout: LegacyWorkoutFixture(exercise: exercise, assignment: assignment, session: session, log: log)
        )

        let stack = try SwiftDataStack(storeURL: url)
        let factory = LocalRepositoryFactory(
            stack: stack, currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        let user = try #require(try await factory.userRepository.currentUser())
        #expect(user.selectedProgramId == program.id)
        #expect(user.createdAt == Date(timeIntervalSince1970: 1000))
        #expect(user.updatedAt == Date(timeIntervalSince1970: 2000))
        #expect(user.goal == nil && user.level == nil && user.avatarPath == nil)
        #expect(try stack.mainContext.fetch(FetchDescriptor<UserEntity>()).first?.revision == 7)
        #expect(try await factory.workoutRepository.fetchSessions(for: userID) == [session])
        #expect(try await factory.workoutRepository.fetchExerciseLogs(sessionId: session.id) == [log])
        #expect(try await factory.workoutProgramRepository.fetchProgram(id: program.id) == program)
        let operations = try stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>())
        let operation = try #require(operations.first)
        #expect(operations.count == 1)
        #expect(operation.revision == 7)
        let payload = try JSONDecoder().decode(UserProfileSyncPayload.self, from: operation.payload)
        #expect(payload.selectedProgramID == program.id)
        #expect(payload.personalization == nil)
    }

    @Test
    func personalizationSurvivesReopeningAndProgramSelection() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "GigaCat.store")
        let user = User(goal: .maintain, level: .advanced, avatarPath: "account/avatar.png")
        try persistProfile(user, at: url)
        let stack = try SwiftDataStack(storeURL: url)
        let factory = LocalRepositoryFactory(
            stack: stack, currentUserIDProvider: CurrentUserContext(userID: user.id)
        )
        #expect(try await factory.userRepository.currentUser() == user)
        let updated = try await factory.userRepository.updateSelectedProgram(for: user.id, programId: nil)
        #expect(updated.goal == user.goal && updated.level == user.level && updated.avatarPath == user.avatarPath)
        let operation = try #require(stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>()).first)
        let payload = try JSONDecoder().decode(UserProfileSyncPayload.self, from: operation.payload)
        #expect(payload.personalization == ProfilePersonalization(
            goal: user.goal, level: user.level, avatarPath: user.avatarPath
        ))
    }

    private func persistProfile(_ user: User, at url: URL) throws {
        let stack = try SwiftDataStack(storeURL: url)
        stack.mainContext.insert(UserMapper.toEntity(user))
        try stack.mainContext.save()
    }

    private func persistLegacyStore(
        at url: URL, userID: UUID, program: WorkoutProgram, day: WorkoutDay,
        workout: LegacyWorkoutFixture
    ) throws {
        let schema = Schema([
            LegacyProfileSchema.UserEntity.self, WorkoutProgramEntity.self, WorkoutDayEntity.self,
            WorkoutDayExerciseEntity.self, ExerciseEntity.self, GigaCatSchemaV1.WorkoutSessionEntity.self,
            ExerciseLogEntity.self, SyncOperationEntity.self
        ])
        let configuration = ModelConfiguration("GigaCat", schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        context.insert(LegacyProfileSchema.UserEntity(id: userID, programID: program.id))
        context.insert(WorkoutProgramMapper.toEntity(program))
        context.insert(WorkoutDayMapper.toEntity(day))
        context.insert(ExerciseMapper.toEntity(workout.exercise))
        context.insert(WorkoutDayExerciseMapper.toEntity(workout.assignment))
        context.insert(GigaCatSchemaV1.WorkoutSessionEntity(
            id: workout.session.id, userId: workout.session.userId, workoutDayId: workout.session.workoutDayId,
            statusRawValue: workout.session.status.rawValue, startedAt: workout.session.startedAt,
            completedAt: workout.session.completedAt
        ))
        context.insert(ExerciseLogMapper.toEntity(workout.log))
        context.insert(SyncOperationEntity(
            userId: userID, aggregateTypeRawValue: "userProfile", aggregateId: userID,
            mutationRawValue: "update",
            payload: Data("{\"selectedProgramID\":\"\(program.id)\"}".utf8), revision: 7
        ))
        try context.save()
    }
}

private struct LegacyWorkoutFixture {
    let exercise: Exercise
    let assignment: WorkoutDayExercise
    let session: WorkoutSession
    let log: ExerciseLog
}

extension ProfileStorageCompatibilityTests {
    @Test
    func fetchedProfileCanPopulateAndResetOptionalFields() async throws {
        let fixture = try LocalProfileFixture()
        let repository = fixture.factory.userRepository
        let old = try await repository.profileSnapshot(for: fixture.userID)
        let populated = User(
            id: fixture.userID, goal: .loseWeight, level: .beginner, avatarPath: "account/avatar.png"
        )
        #expect(try await repository.applyFetchedProfile(populated, ifUnchangedSince: old))
        #expect(try await repository.user(id: fixture.userID) == populated)
        let snapshot = try await repository.profileSnapshot(for: fixture.userID)
        let cleared = User(id: fixture.userID)
        #expect(try await repository.applyFetchedProfile(cleared, ifUnchangedSince: snapshot))
        #expect(try await repository.user(id: fixture.userID) == cleared)
    }

    @Test
    func staleAcknowledgementCannotOverwriteNewerPersonalization() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let user = User(goal: .buildMuscle, level: .advanced, avatarPath: "account/avatar.png")
        let entity = UserMapper.toEntity(user)
        stack.mainContext.insert(entity)
        try UserProfileOutboxWriter(context: stack.mainContext).enqueueProfileUpdate(for: entity)
        try stack.mainContext.save()
        let outbox = LocalSyncOutboxRepository(context: stack.mainContext)
        let operation = try #require(try outbox.claimNextReadyOperation(for: user.id, now: Date()))
        entity.goal = .maintain
        entity.level = .beginner
        entity.avatarPath = nil
        entity.revision += 1
        try UserProfileOutboxWriter(context: stack.mainContext).enqueueProfileUpdate(for: entity)
        try stack.mainContext.save()
        try outbox.complete(operation, with: .userProfile(user))
        #expect(entity.goal == .maintain && entity.level == .beginner && entity.avatarPath == nil)
        #expect(try outbox.operationCount(for: user.id) == 1)
    }
}
