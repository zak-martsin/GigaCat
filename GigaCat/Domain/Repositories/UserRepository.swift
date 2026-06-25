import Foundation

/// Domain-facing access to authenticated user data and program selection state.
protocol UserRepository: Sendable {
    func currentUser() async throws -> User?
    func user(appleUserId: String) async throws -> User?
    func save(_ user: User) async throws
    func updateSelectedProgram(for userId: UUID, programId: UUID?) async throws -> User
}
