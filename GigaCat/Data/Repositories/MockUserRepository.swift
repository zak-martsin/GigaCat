import Foundation

/// In-memory user repository used before SwiftData and Supabase integrations exist.
struct MockUserRepository: UserRepository {
    private let store: MockDataStore

    nonisolated init(store: MockDataStore) {
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

    func profileSnapshot(for userID: UUID) async throws -> LocalProfileSnapshot {
        await store.profileSnapshot(for: userID)
    }

    func applyFetchedProfile(
        _ user: User,
        ifUnchangedSince snapshot: LocalProfileSnapshot
    ) async throws -> Bool {
        await store.applyFetchedProfile(user, ifUnchangedSince: snapshot)
    }
}
