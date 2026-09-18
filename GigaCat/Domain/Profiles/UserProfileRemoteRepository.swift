import Foundation

/// Reads and updates app profile data without exposing the Supabase SDK.
protocol UserProfileRemoteRepository: Sendable {
    func profile(for userID: UUID) async throws -> User
    func updateProfile(
        for userID: UUID,
        selectedProgramID: UUID?
    ) async throws -> User
}
