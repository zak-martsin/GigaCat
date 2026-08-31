import Foundation

/// In-memory authentication service for previews and deterministic app tests.
actor MockAuthenticationService: AuthenticationService {
    private var currentAccountStorage: AuthenticatedAccount?
    private var accountsByEmail: [String: AuthenticatedAccount]
    private let requiresEmailConfirmation: Bool

    init(
        currentAccount: AuthenticatedAccount? = nil,
        requiresEmailConfirmation: Bool = false
    ) {
        currentAccountStorage = currentAccount
        self.requiresEmailConfirmation = requiresEmailConfirmation

        if let currentAccount,
           let email = currentAccount.email {
            accountsByEmail = [Self.normalized(email): currentAccount]
        } else {
            accountsByEmail = [:]
        }
    }

    func currentAccount() -> AuthenticatedAccount? {
        currentAccountStorage
    }

    func signUp(
        email: String,
        password _: String
    ) -> RegistrationResult {
        let account = account(for: email)

        guard !requiresEmailConfirmation else {
            return .emailConfirmationRequired
        }

        currentAccountStorage = account
        return .authenticated(account)
    }

    func signIn(
        email: String,
        password _: String
    ) -> AuthenticatedAccount {
        let account = account(for: email)
        currentAccountStorage = account
        return account
    }

    func handleCallback(_ url: URL) throws -> AuthenticatedAccount {
        guard let currentAccountStorage else {
            throw AuthenticationError.unexpected(
                "No authentication callback is available in the mock service."
            )
        }

        return currentAccountStorage
    }

    func signOut() {
        currentAccountStorage = nil
    }

    private func account(for email: String) -> AuthenticatedAccount {
        let normalizedEmail = Self.normalized(email)
        if let account = accountsByEmail[normalizedEmail] {
            return account
        }

        let account = AuthenticatedAccount(
            id: UUID(),
            email: normalizedEmail
        )
        accountsByEmail[normalizedEmail] = account
        return account
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
