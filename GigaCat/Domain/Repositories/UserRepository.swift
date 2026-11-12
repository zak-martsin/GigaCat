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
    /// Atomically saves training inputs, active-session recommendations and a profile outbox entry.
    func updateTrainingPreferences(for userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) async throws -> User
    func profileSnapshot(for userID: UUID) async throws -> LocalProfileSnapshot
    /// Accepts explicit recovery only if the fetched version is still current and all outgoing changes have failed.
    func discardFailedProfileChanges(applying user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) async throws -> Bool
    /// Applies a fetched profile and active-session targets only if no local mutation remains unresolved.
    func applyFetchedProfile(_ user: User, ifUnchangedSince snapshot: LocalProfileSnapshot) async throws -> Bool
}
