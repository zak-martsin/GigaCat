import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct TrainingSessionLifecycleTests {
    @Test(arguments: [false, true])
    func manualAndAutomaticCompletionFreezeRecommendations(automatic: Bool) async throws {
        let fixture = try TrainingSessionFixture()
        let repository = fixture.factory.workoutRepository
        let session = try await fixture.start()
        if automatic {
            _ = try await WorkoutSessionExpirationService(workoutRepository: repository).reconcile(
                for: fixture.user.id, now: session.startedAt.addingTimeInterval(6 * 60 * 60)
            )
        } else {
            _ = try await repository.completeSession(
                sessionId: session.id, userId: fixture.user.id, completedAt: session.startedAt.addingTimeInterval(60)
            )
        }
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        let completed = try #require(try await repository.fetchSessions(for: fixture.user.id).first)
        #expect(completed.status == .completed)
        #expect(completed.exerciseTargets == session.exerciseTargets)
        let future = try await fixture.start()
        #expect(future.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
    }

    @Test
    func completionAndProgramSelectionPreserveTargets() async throws {
        let fixture = try TrainingSessionFixture()
        let session = try await fixture.start()
        _ = try await fixture.factory.workoutRepository.completeSessionAndSelectProgram(
            sessionId: session.id, completedAt: session.startedAt.addingTimeInterval(60),
            userId: fixture.user.id, programId: fixture.day.programId
        )
        let completed = try #require(try await fixture.factory.workoutRepository.fetchSessions(for: fixture.user.id).first)
        #expect(completed.exerciseTargets == session.exerciseTargets)
        #expect(completed.status == .completed)
    }

    @Test
    func legacyActiveBackfillsOnceButCompletedHistoryStaysUnknown() async throws {
        let fixture = try TrainingSessionFixture()
        let context = fixture.stack.mainContext
        let active = try WorkoutSession(userId: fixture.user.id, workoutDayId: fixture.day.id)
        let completed = try active.markCompleted(at: active.startedAt)
        // Separate identities are needed to represent legacy history and the current workout.
        let history = try WorkoutSession(
            userId: completed.userId, workoutDayId: completed.workoutDayId, status: .completed,
            startedAt: completed.startedAt, completedAt: completed.completedAt
        )
        context.insert(WorkoutSessionMapper.toEntity(active))
        context.insert(WorkoutSessionMapper.toEntity(history))
        try context.save()
        let first = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(first.exerciseTargets?.map(\.targetSets) == [4, 5, 4])
        let assignment = try #require(context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>()).first)
        assignment.targetSets = 9
        try context.save()
        let second = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(second.exerciseTargets == first.exerciseTargets)
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        let after = try #require(try await fixture.factory.workoutRepository.activeSession(for: fixture.user.id))
        #expect(after.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
        #expect(try await fixture.factory.workoutRepository.fetchSessions(for: fixture.user.id)
            .first { $0.id == history.id } == history)
    }

    @Test
    func changingOneProfileDoesNotAffectOtherUsersActiveSession() async throws {
        let fixture = try TrainingSessionFixture()
        let other = User(goal: .buildMuscle, level: .advanced)
        try await fixture.factory.userRepository.save(other)
        let otherSession = try await fixture.factory.workoutRepository.startSession(
            userId: other.id, workoutDayId: fixture.day.id, startedAt: Date()
        )
        _ = try await fixture.start()
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        #expect(try await fixture.factory.workoutRepository.activeSession(for: other.id) == otherSession)
        #expect(try await fixture.factory.userRepository.user(id: other.id) == other)
    }

    @Test
    func mockRepositoriesFollowTheSameTrainingRules() async throws {
        let fixture = try TrainingSessionFixture()
        let store = MockDataStore(users: [fixture.user], workoutDays: [fixture.day], dayExercises: fixture.assignments)
        let repository = MockWorkoutRepository(store: store)
        let session = try await repository.startSession(userId: fixture.user.id, workoutDayId: fixture.day.id, startedAt: Date())
        #expect(session.exerciseTargets?.map(\.targetSets) == [4, 5, 4])
        _ = try await MockUserRepository(store: store).updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        let active = try #require(try await repository.activeSession(for: fixture.user.id))
        #expect(active.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
    }
}
