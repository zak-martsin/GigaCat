import Foundation

/// In-memory user repository used before SwiftData and Supabase integrations exist.
struct MockUserRepository: UserRepository {
    private let store: MockDataStore
    private let profileChanges: ProfileChangeSource

    nonisolated init(store: MockDataStore, profileChanges: ProfileChangeSource = ProfileChangeSource()) {
        self.profileChanges = profileChanges
        self.store = store
    }

    func currentUser() async throws -> User? {
        await store.currentUser()
    }

    func user(id: UUID) async throws -> User? {
        await store.user(id: id)
    }

    func save(_ user: User) async throws {
        await store.saveUser(user)
    }

    func updateSelectedProgram(for userId: UUID, programId: UUID?) async throws -> User {
        try await store.updateSelectedProgram(for: userId, programId: programId)
    }

    func updateTrainingPreferences(for userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) async throws -> User {
        try await store.updateTrainingPreferences(for: userID, goal: goal, level: level)
    }

    func discardFailedProfileChanges(applying user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) async throws -> Bool {
        // Mock stores have no persistent outbox; only the profile version guard is relevant.
        try await applyFetchedProfile(user, ifUnchangedSince: snapshot)
    }

    func profileSnapshot(for userID: UUID) async throws -> LocalProfileSnapshot {
        await store.profileSnapshot(for: userID)
    }

    func applyFetchedProfile(
        _ user: User,
        ifUnchangedSince snapshot: LocalProfileSnapshot
    ) async throws -> Bool {
        let changed = try await store.applyFetchedProfile(user, ifUnchangedSince: snapshot)
        if changed { profileChanges.publish(userID: user.id) }
        return changed
    }
}
