import Foundation

/// In-memory user repository used before SwiftData and Supabase integrations exist.
struct MockUserRepository: UserRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func currentUser() async throws -> User? {
        await store.currentUser()
    }

    func user(appleUserId: String) async throws -> User? {
        await store.user(appleUserId: appleUserId)
    }

    func save(_ user: User) async throws {
        await store.saveUser(user)
    }

    func updateSelectedProgram(for userId: UUID, programId: UUID?) async throws -> User {
        try await store.updateSelectedProgram(for: userId, programId: programId)
    }
}
