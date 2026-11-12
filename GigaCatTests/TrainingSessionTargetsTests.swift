import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct TrainingSessionTargetsTests {
    @Test(arguments: [false, true])
    func bothCreationPathsCaptureAllExercises(startWithSet: Bool) async throws {
        let fixture = try TrainingSessionFixture()
        let session: WorkoutSession
        if startWithSet {
            session = try await fixture.factory.workoutRepository.saveSet(fixture.input(setNumber: 6)).session
        } else {
            session = try await fixture.start()
        }
        let targets = try #require(session.exerciseTargets)
        #expect(targets.map(\.workoutDayExerciseID) == fixture.assignments.map(\.id))
        #expect(targets.map(\.targetSets) == [4, 5, 4])
        #expect(targets.map(\.programOverride) == [nil, 5, nil])
        let reopened = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(reopened.exerciseTargets == targets)
        #expect(session.isActive)
    }

    @Test
    func updateRecalculatesEntireActiveSessionWithoutTouchingLogsOrHistory() async throws {
        let fixture = try TrainingSessionFixture()
        let repository = fixture.factory.workoutRepository
        let historical = try await fixture.start()
        let completed = try await repository.completeSession(
            sessionId: historical.id, userId: fixture.user.id, completedAt: Date(timeIntervalSince1970: 1050)
        )
        let active = try await repository.saveSet(fixture.input(setNumber: 4)).session
        let logs = try await repository.fetchExerciseLogs(sessionId: active.id)
        let useCase = UpdateTrainingProfileUseCase(userRepository: fixture.factory.userRepository)
        let updated = try await useCase.execute(userID: fixture.user.id, goal: .maintain, level: .advanced)
        let after = try #require(try await repository.activeSession(for: fixture.user.id))
        #expect(after.exerciseTargets?.map(\.targetSets) == [3, 5, 3])
        #expect(after.id == active.id && after.startedAt == active.startedAt && after.isActive)
        #expect(updated.avatarPath == fixture.user.avatarPath)
        #expect(try await repository.fetchExerciseLogs(sessionId: active.id) == logs)
        let cleared = try await useCase.execute(userID: fixture.user.id, goal: nil, level: .advanced)
        let reset = try #require(try await repository.activeSession(for: fixture.user.id))
        #expect(cleared.goal == nil && cleared.level == .advanced)
        #expect(reset.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
        #expect(try await repository.fetchExerciseLogs(sessionId: active.id) == logs)
        let sessions = try await repository.fetchSessions(for: fixture.user.id)
        #expect(sessions.first { $0.id == completed.id } == completed)
        #expect(try await fixture.factory.workoutProgramRepository.fetchWorkoutDayExercises(
            workoutDayId: fixture.day.id
        ) == fixture.assignments)
        let entity = try #require(fixture.stack.mainContext.fetch(FetchDescriptor<UserEntity>()).first)
        #expect(entity.revision == 2)
        let operations = try fixture.stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>())
        #expect(operations.count == 1)
        let payload = try JSONDecoder().decode(UserProfileSyncPayload.self, from: #require(operations.first).payload)
        #expect(payload.personalization?.goal == nil && payload.personalization?.level == .advanced)
    }

    @Test(arguments: [false, true])
    func partialProfileDefaultsWithoutOverridingProgram(clearGoal: Bool) async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(
            for: fixture.user.id, goal: clearGoal ? nil : .buildMuscle, level: clearGoal ? .advanced : nil
        )
        let active = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(active.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
    }

    @Test
    func previewUsesSamePolicyWithoutCreatingSession() async throws {
        let fixture = try TrainingSessionFixture()
        let service = WorkoutRecommendationService(
            userRepository: fixture.factory.userRepository, programRepository: fixture.factory.workoutProgramRepository
        )
        let targets = try await service.recommendations(userID: fixture.user.id, workoutDayID: fixture.day.id)
        #expect(targets.map(\.targetSets) == [4, 5, 4])
        #expect(try await fixture.factory.workoutRepository.fetchSessions(for: fixture.user.id).isEmpty)
    }

    @Test
    func repeatingSamePreferencesIsANoOp() async throws {
        let fixture = try TrainingSessionFixture()
        let active = try await fixture.start()
        let updated = try await fixture.factory.userRepository.updateTrainingPreferences(
            for: fixture.user.id, goal: fixture.user.goal, level: fixture.user.level
        )
        #expect(updated == fixture.user)
        #expect(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id) == active)
        #expect(try fixture.factory.syncOutboxRepository.operationCount(for: fixture.user.id) == 0)
    }

    @Test
    func invalidLegacyRecommendationLeavesProfileSessionAndOutboxUnchanged() async throws {
        let fixture = try TrainingSessionFixture()
        let legacy = try WorkoutSession(userId: fixture.user.id, workoutDayId: fixture.day.id)
        let context = fixture.stack.mainContext
        context.insert(WorkoutSessionMapper.toEntity(legacy))
        let assignment = try #require(context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>()).first)
        assignment.targetSets = 0
        try context.save()
        await #expect(throws: DomainValidationError.nonPositiveValue(field: "targetSets")) {
            try await fixture.factory.userRepository.updateTrainingPreferences(
                for: fixture.user.id, goal: .maintain, level: .beginner
            )
        }
        #expect(try await fixture.factory.userRepository.user(id: fixture.user.id) == fixture.user)
        #expect(try context.fetch(FetchDescriptor<WorkoutSessionEntity>()).first?.exerciseTargets == nil)
        #expect(try fixture.factory.syncOutboxRepository.operationCount(for: fixture.user.id) == 0)
    }
}
