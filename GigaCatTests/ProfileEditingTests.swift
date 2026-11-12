import Foundation
import Testing
@testable import GigaCat

@MainActor
struct ProfileEditingTests {
    @Test
    func emptyAndPartialProfilesAreValidAndCancelDiscardsDraft() async throws {
        let repository = ProfileEditingRepositoryStub(user: User(goal: .maintain))
        let model = makeModel(repository: repository)
        await model.load()
        #expect(model.isLoaded && !model.canSave)
        #expect(model.goal == .maintain && model.level == nil)
        #expect(model.email == "athlete@example.com")
        model.goal = .buildMuscle
        model.level = .advanced
        #expect(model.canSave)
        await model.load()
        #expect(model.goal == .maintain && model.level == nil && !model.hasChanges)
        #expect(repository.saveCount == 0)
    }

    @Test
    func saveAndResetCommitLocallyAndAnnounceTrainingChange() async throws {
        let fixture = try TrainingSessionFixture()
        _ = try await fixture.start()
        var changes: [AppDataChange] = []
        let model = ProfileSheetViewModel(
            recoveryService: ProfileEditingRecoveryStub(), userID: fixture.user.id,
            email: "athlete@example.com", userRepository: fixture.factory.userRepository,
            onDataChanged: { changes.append($0) }
        )
        await model.load()
        model.goal = nil
        #expect(await model.save())
        #expect(!model.hasChanges && !model.isSaving && model.errorMessage == nil)
        let user = try #require(try await fixture.factory.userRepository.user(id: fixture.user.id))
        #expect(user.goal == nil && user.level == .intermediate)
        #expect(user.avatarPath == fixture.user.avatarPath)
        #expect(try await fixture.factory.workoutRepository.activeSession(for: user.id)?.exerciseTargets?.map(\.targetSets) == [2, 5, 2])
        #expect(try fixture.factory.syncOutboxRepository.operationCount(for: user.id) == 1)
        #expect(changes == [.trainingPreferences])
    }

    @Test
    func failedSaveKeepsEditsAndAllowsRetry() async {
        let repository = ProfileEditingRepositoryStub(user: User())
        let model = makeModel(repository: repository)
        await model.load()
        repository.rejectSave = true
        model.goal = .buildMuscle
        model.level = .advanced
        #expect(await !model.save())
        #expect(model.canSave && model.goal == .buildMuscle && model.level == .advanced)
        #expect(model.errorMessage != nil)
        repository.rejectSave = false
        #expect(await model.save())
        #expect(model.errorMessage == nil)
    }

    @Test
    func remoteRefreshDoesNotOverwriteAnEditingDraft() async {
        let repository = ProfileEditingRepositoryStub(user: User())
        let model = makeModel(repository: repository)
        await model.load()
        model.goal = .loseWeight
        repository.value = repository.value?.updatingTraining(goal: .buildMuscle, level: .advanced)
        await model.refreshIfUnedited()
        #expect(model.goal == .loseWeight && model.level == nil)
        await model.load()
        #expect(model.goal == .buildMuscle && model.level == .advanced)
    }

    @Test
    func unavailableProfileCannotBeSaved() async {
        let repository = ProfileEditingRepositoryStub(user: nil)
        let model = makeModel(repository: repository)
        await model.load()
        #expect(!model.isLoaded && !model.canSave && model.errorMessage != nil)
        #expect(await !model.save())
    }

    private func makeModel(repository: ProfileEditingRepositoryStub) -> ProfileSheetViewModel {
        ProfileSheetViewModel(
            recoveryService: ProfileEditingRecoveryStub(), userID: repository.value?.id ?? UUID(),
            email: "athlete@example.com", userRepository: repository
        )
    }
}

@MainActor
private final class ProfileEditingRepositoryStub: UserRepository {
    var value: User?
    var rejectSave = false
    var saveCount = 0
    init(user: User?) { value = user }
    func currentUser() -> User? { value }
    func user(id: UUID) -> User? { value }
    func save(_ user: User) { value = user }
    func updateSelectedProgram(for _: UUID, programId: UUID?) throws -> User {
        guard let value else { throw RepositoryError.userNotFound }
        return value.selectingProgram(programId)
    }
    func updateTrainingPreferences(for _: UUID, goal: TrainingGoal?, level: TrainingLevel?) throws -> User {
        guard let value, !rejectSave else { throw RepositoryError.userNotFound }
        self.value = value.updatingTraining(goal: goal, level: level)
        saveCount += 1
        return self.value ?? value
    }
    func profileSnapshot(for userID: UUID) -> LocalProfileSnapshot { LocalProfileSnapshot(userID: userID, user: value, revision: 0) }
    func applyFetchedProfile(_: User, ifUnchangedSince _: LocalProfileSnapshot) -> Bool { false }
    func discardFailedProfileChanges(applying _: User, ifUnchangedSince _: LocalProfileSnapshot) -> Bool { false }
}

@MainActor
private final class ProfileEditingRecoveryStub: ProfileSyncRecovering {
    func status(for _: UUID) -> ProfileSyncStatus { .waiting }
    func retryFailedChange(for _: UUID) async throws {}
    func discardFailedLocalChange(for _: UUID) async throws -> Bool { false }
}
