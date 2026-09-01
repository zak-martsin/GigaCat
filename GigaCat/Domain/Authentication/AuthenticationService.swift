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

    func requestPasswordRecovery(email: String) async throws

    /// Exchanges a recovery deep link for the temporary session required to change the password.
    func preparePasswordRecovery(from url: URL) async throws

    func updatePassword(_ password: String) async throws -> AuthenticatedAccount

    func signOut() async throws
}
