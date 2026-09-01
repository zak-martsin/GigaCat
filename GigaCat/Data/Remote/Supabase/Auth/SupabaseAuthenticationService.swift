import Foundation
import Supabase

/// Implements the domain authentication contract using Supabase Auth.
struct SupabaseAuthenticationService: AuthenticationService {
    private let authClient: any SupabaseAuthClient

    init(client: SupabaseClient) {
        authClient = LiveSupabaseAuthClient(client: client)
    }

    init(authClient: any SupabaseAuthClient) {
        self.authClient = authClient
    }

    func currentAccount() async throws -> AuthenticatedAccount? {
        do {
            return try await authClient.currentUser().map {
                Self.account(from: $0)
            }
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func signUp(
        email: String,
        password: String
    ) async throws -> RegistrationResult {
        do {
            let response = try await authClient.signUp(
                email: email,
                password: password
            )

            switch response {
            case .session(let session):
                return .authenticated(Self.account(from: session.user))
            case .user:
                return .emailConfirmationRequired
            }
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthenticatedAccount {
        do {
            let session = try await authClient.signIn(
                email: email,
                password: password
            )
            return Self.account(from: session.user)
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func handleCallback(_ url: URL) async throws -> AuthenticatedAccount {
        do {
            let session = try await authClient.session(from: url)
            return Self.account(from: session.user)
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func requestPasswordRecovery(email: String) async throws {
        guard let redirectURL = SupabaseAuthRedirect.passwordRecovery else {
            throw AuthenticationError.serviceUnavailable
        }

        do {
            try await authClient.requestPasswordRecovery(
                email: email,
                redirectTo: redirectURL
            )
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func preparePasswordRecovery(from url: URL) async throws {
        do {
            _ = try await authClient.session(from: url)
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func updatePassword(
        _ password: String
    ) async throws -> AuthenticatedAccount {
        do {
            let user = try await authClient.updatePassword(password)
            return Self.account(from: user)
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    func signOut() async throws {
        do {
            try await authClient.signOut()
        } catch {
            throw Self.authenticationError(from: error)
        }
    }

    static func authenticationError(from error: any Error) -> AuthenticationError {
        guard let authError = error as? AuthError else {
            return .unexpected(error.localizedDescription)
        }

        switch authError.errorCode {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailNotConfirmed:
            return .emailNotConfirmed
        case .emailExists, .userAlreadyExists:
            return .accountAlreadyExists
        case .weakPassword:
            return .weakPassword
        case .overRequestRateLimit, .overEmailSendRateLimit:
            return .tooManyRequests
        case .emailProviderDisabled, .signupDisabled, .unexpectedFailure:
            return .serviceUnavailable
        default:
            return .unexpected(authError.localizedDescription)
        }
    }

    private static func account(from user: Auth.User) -> AuthenticatedAccount {
        AuthenticatedAccount(id: user.id, email: user.email)
    }
}
