import Foundation

/// Captures the local profile version before an asynchronous remote read.
struct LocalProfileSnapshot: Sendable {
    let userID: UUID
    let user: User?
    let revision: Int?
}

/// Domain-facing access to local profile data and program selection state.
@MainActor
protocol UserRepository {
    func currentUser() async throws -> User?
    func user(id: UUID) async throws -> User?
    func save(_ user: User) async throws
    func updateSelectedProgram(for userId: UUID, programId: UUID?) async throws -> User
    func profileSnapshot(for userID: UUID) async throws -> LocalProfileSnapshot
    /// Applies a fetched profile only if no local selection changed or remains in the outbox.
    func applyFetchedProfile(_ user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) async throws -> Bool
}
