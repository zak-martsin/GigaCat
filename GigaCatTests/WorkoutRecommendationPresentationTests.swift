import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct WorkoutRecommendationPresentationTests {
    @Test
    func openExerciseRetainsIdentityManualRowsAndDraftsWhenProfileChanges() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        let contextService = WorkoutContextService(
            userRepository: fixture.factory.userRepository, workoutProgramRepository: fixture.factory.workoutProgramRepository,
            workoutRepository: fixture.factory.workoutRepository
        )
        let model = WorkoutViewModel(
            contextService: contextService, workoutRepository: fixture.factory.workoutRepository,
            artworkService: ArtworkServiceTestDouble()
        )
        await model.load()
        let day = try #require(model.selectedDayContent)
        let id = fixture.assignments[0].id
        let detail = try #require(model.makeExerciseViewModel(dayContent: day, initialDayExerciseID: id))
        let key = WorkoutSetDraftKey(dayExerciseID: id, setNumber: 4)
        let entered = WorkoutSetDraft(weightText: "72.5", repsText: "9")
        detail.drafts.update(entered, for: key)
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        model.invalidate()
        await model.loadIfNeeded()
        let refreshedDay = try #require(model.selectedDayContent)
        let refreshed = try #require(model.makeExerciseViewModel(dayContent: refreshedDay, initialDayExerciseID: id))
        #expect(refreshed === detail)
        #expect(detail.selectedExercise?.recommendedSets == 2)
        #expect(detail.setCount(dayExerciseID: id) == 4)
        #expect(detail.drafts.draft(for: key, fallback: WorkoutSetDraft(weightText: "", repsText: "")) == entered)
        detail.addSet()
        #expect(detail.setCount(dayExerciseID: id) == 5)
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: .maintain, level: .advanced)
        model.invalidate()
        await model.loadIfNeeded()
        #expect(detail.selectedExercise?.recommendedSets == 3 && detail.setCount(dayExerciseID: id) == 5)
    }

    @Test
    func contextUsesProfileForPreviewAndStoredTargetsDuringSession() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.factory.userRepository.updateSelectedProgram(for: fixture.user.id, programId: fixture.day.programId)
        let service = WorkoutContextService(
            userRepository: fixture.factory.userRepository, workoutProgramRepository: fixture.factory.workoutProgramRepository,
            workoutRepository: fixture.factory.workoutRepository
        )
        #expect(try await service.loadContext()?.dayContents.first?.exercises.map(\.recommendedSets) == [4, 5, 4])
        _ = try await fixture.start()
        // A catalog change must not replace the override captured when the session started.
        let overrideID = fixture.assignments[1].id
        let assignment = try #require(fixture.stack.mainContext.fetch(FetchDescriptor<WorkoutDayExerciseEntity>(
            predicate: #Predicate { $0.id == overrideID }
        )).first)
        assignment.targetSets = 8
        try fixture.stack.mainContext.save()
        let remote = fixture.user.updatingTraining(goal: nil, level: nil)
        let snapshot = try await fixture.factory.userRepository.profileSnapshot(for: fixture.user.id)
        #expect(try await fixture.factory.userRepository.applyFetchedProfile(remote, ifUnchangedSince: snapshot) == false)
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: nil, level: nil)
        #expect(try await service.loadContext()?.dayContents.first?.exercises.map(\.recommendedSets) == [2, 5, 2])
    }

    @Test
    func recommendationAndVisibleCountStaySeparateWhenCompletedSetsExceedTarget() async throws {
        let fixture = try TrainingSessionFixture()
        for number in 1...4 { _ = try await fixture.factory.workoutRepository.saveSet(fixture.input(setNumber: number)) }
        _ = try await fixture.factory.userRepository.updateTrainingPreferences(for: fixture.user.id, goal: .maintain, level: .advanced)
        let service = WorkoutContextService(
            userRepository: fixture.factory.userRepository, workoutProgramRepository: fixture.factory.workoutProgramRepository,
            workoutRepository: fixture.factory.workoutRepository
        )
        let context = try #require(try await service.loadContext())
        let mapped = try #require(WorkoutViewDataMapper().map(context: context, selectedDayID: fixture.day.id))
        let exercise = try #require(mapped.selectedDay.exercises.first)
        #expect(exercise.recommendedSets == 3 && exercise.completedSets == 4 && exercise.setCount == 4)
    }
}
