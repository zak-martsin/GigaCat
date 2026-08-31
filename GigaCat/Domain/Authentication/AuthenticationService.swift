import Foundation

/// Provides account registration and session operations without exposing a concrete auth vendor.
protocol AuthenticationService: Sendable {
    func currentAccount() async throws -> AuthenticatedAccount?

    func signUp(
        email: String,
        password: String
    ) async throws -> RegistrationResult

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthenticatedAccount

    func handleCallback(_ url: URL) async throws -> AuthenticatedAccount

    func signOut() async throws
}
