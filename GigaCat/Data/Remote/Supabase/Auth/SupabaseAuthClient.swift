import Supabase
import Foundation

/// Narrow SDK boundary used to test authentication without making network requests.
protocol SupabaseAuthClient: Sendable {
    func currentUser() async throws -> Auth.User?
    func signUp(email: String, password: String) async throws -> AuthResponse
    func signIn(email: String, password: String) async throws -> Session
    func session(from url: URL) async throws -> Session
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

    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    func session(from url: URL) async throws -> Session {
        try await client.auth.session(from: url)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
