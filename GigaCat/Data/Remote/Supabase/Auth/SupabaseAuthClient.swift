import Supabase
import Foundation

/// Narrow SDK boundary used to test authentication without making network requests.
protocol SupabaseAuthClient: Sendable {
    func currentUser() async throws -> Auth.User?
    func refreshedSessionUserIDs() -> AsyncStream<UUID>
    func signUp(email: String, password: String) async throws -> AuthResponse
    func signIn(email: String, password: String) async throws -> Session
    func session(from url: URL) async throws -> Session
    func requestPasswordRecovery(email: String, redirectTo: URL) async throws
    func updatePassword(_ password: String) async throws -> Auth.User
    func signOut() async throws
}

struct LiveSupabaseAuthClient: SupabaseAuthClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUser() async throws -> Auth.User? {
        guard client.auth.currentSession != nil else {
            return nil
        }

        return try await client.auth.session.user
    }

    func refreshedSessionUserIDs() -> AsyncStream<UUID> {
        AsyncStream { continuation in
            let observer = Task {
                for await (event, session) in client.auth.authStateChanges {
                    guard event == .tokenRefreshed,
                          let session,
                          !session.isExpired else {
                        continue
                    }
                    continuation.yield(session.user.id)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in observer.cancel() }
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    func session(from url: URL) async throws -> Session {
        try await client.auth.session(from: url)
    }

    func requestPasswordRecovery(
        email: String,
        redirectTo: URL
    ) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: redirectTo
        )
    }

    func updatePassword(_ password: String) async throws -> Auth.User {
        try await client.auth.update(
            user: UserAttributes(password: password)
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
