import Foundation
import Supabase
import Testing
@testable import GigaCat

struct SupabaseAuthenticationServiceTests {

    @Test
    func currentAccountMapsSupabaseUser() async throws {
        let user = makeSupabaseUser(email: "user@example.com")
        let authClient = SupabaseAuthClientSpy(currentUser: user)
        let service = SupabaseAuthenticationService(authClient: authClient)

        let account = try await service.currentAccount()

        #expect(account == AuthenticatedAccount(id: user.id, email: user.email))
    }

    @Test
    func signUpReturnsAuthenticatedAccountWhenSessionIsCreated() async throws {
        let session = makeSession(email: "user@example.com")
        let authClient = SupabaseAuthClientSpy(signUpResponse: .session(session))
        let service = SupabaseAuthenticationService(authClient: authClient)

        let result = try await service.signUp(
            email: "user@example.com",
            password: "password"
        )

        #expect(
            result == .authenticated(
                AuthenticatedAccount(
                    id: session.user.id,
                    email: session.user.email
                )
            )
        )
    }

    @Test
    func signUpRequiresConfirmationWhenSupabaseReturnsOnlyUser() async throws {
        let user = makeSupabaseUser(email: "user@example.com")
        let authClient = SupabaseAuthClientSpy(signUpResponse: .user(user))
        let service = SupabaseAuthenticationService(authClient: authClient)

        let result = try await service.signUp(
            email: "user@example.com",
            password: "password"
        )

        #expect(result == .emailConfirmationRequired)
    }

    @Test
    func signInMapsSessionAndSignOutUsesSDKClient() async throws {
        let session = makeSession(email: "user@example.com")
        let authClient = SupabaseAuthClientSpy(signInSession: session)
        let service = SupabaseAuthenticationService(authClient: authClient)

        let account = try await service.signIn(
            email: "user@example.com",
            password: "password"
        )
        try await service.signOut()

        #expect(account.id == session.user.id)
        #expect(await authClient.didSignOut())
    }

    @Test
    func callbackURLCreatesAndMapsSession() async throws {
        let callbackURL = try #require(
            URL(string: "com.zakmartsin.gigacat://auth-callback?code=test-code")
        )
        let session = makeSession(email: "user@example.com")
        let authClient = SupabaseAuthClientSpy(callbackSession: session)
        let service = SupabaseAuthenticationService(authClient: authClient)

        let account = try await service.handleCallback(callbackURL)

        #expect(await authClient.lastCallbackURL() == callbackURL)
        #expect(
            account == AuthenticatedAccount(
                id: session.user.id,
                email: session.user.email
            )
        )
    }

    @Test
    func mapsCommonSupabaseErrorsToDomainErrors() {
        #expect(
            SupabaseAuthenticationService.authenticationError(
                from: AuthError.weakPassword(
                    message: "Password is too weak",
                    reasons: ["length"]
                )
            ) == .weakPassword
        )
        #expect(
            SupabaseAuthenticationService.authenticationError(
                from: AuthError.sessionMissing
            ) == .unexpected("Auth session missing.")
        )
    }
}

private actor SupabaseAuthClientSpy: SupabaseAuthClient {
    private let currentUserValue: Auth.User?
    private let signUpResponse: AuthResponse?
    private let signInSession: Session?
    private let callbackSession: Session?
    private var receivedCallbackURL: URL?
    private var signedOut = false

    init(
        currentUser: Auth.User? = nil,
        signUpResponse: AuthResponse? = nil,
        signInSession: Session? = nil,
        callbackSession: Session? = nil
    ) {
        currentUserValue = currentUser
        self.signUpResponse = signUpResponse
        self.signInSession = signInSession
        self.callbackSession = callbackSession
    }

    func currentUser() -> Auth.User? {
        currentUserValue
    }

    func signUp(email _: String, password _: String) throws -> AuthResponse {
        guard let signUpResponse else {
            throw TestAuthClientError.missingStub
        }
        return signUpResponse
    }

    func session(from url: URL) throws -> Session {
        receivedCallbackURL = url
        guard let callbackSession else {
            throw TestAuthClientError.missingStub
        }
        return callbackSession
    }

    func signIn(email _: String, password _: String) throws -> Session {
        guard let signInSession else {
            throw TestAuthClientError.missingStub
        }
        return signInSession
    }

    func signOut() {
        signedOut = true
    }

    func didSignOut() -> Bool {
        signedOut
    }

    func lastCallbackURL() -> URL? {
        receivedCallbackURL
    }
}

private enum TestAuthClientError: Error {
    case missingStub
}

private func makeSession(email: String) -> Session {
    Session(
        accessToken: "access-token",
        tokenType: "bearer",
        expiresIn: 3_600,
        expiresAt: Date().addingTimeInterval(3_600).timeIntervalSince1970,
        refreshToken: "refresh-token",
        user: makeSupabaseUser(email: email)
    )
}

private func makeSupabaseUser(email: String) -> Auth.User {
    let now = Date()
    return Auth.User(
        id: UUID(),
        appMetadata: [:],
        userMetadata: [:],
        aud: "authenticated",
        email: email,
        createdAt: now,
        updatedAt: now
    )
}
