import Foundation
import Observation

enum AuthenticationMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: Self { self }

    var title: String {
        switch self {
        case .signIn:
            "Sign In"
        case .signUp:
            "Create Account"
        }
    }
}

enum AuthenticationSessionState: Equatable {
    case checking
    case signedOut
    case authenticated(AuthenticatedAccount)
    case failed(String)
}

/// Owns the email authentication form and the app's Supabase session state.
@MainActor
@Observable
final class AuthenticationViewModel {
    // MARK: - Presentation State

    var mode: AuthenticationMode = .signIn {
        didSet {
            guard mode != oldValue else { return }
            errorMessage = nil
            noticeMessage = nil
        }
    }
    var email = ""
    var password = ""

    private(set) var sessionState: AuthenticationSessionState = .checking
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private(set) var noticeMessage: String?

    var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty && !isSubmitting
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let authenticationService: any AuthenticationService

    @ObservationIgnored
    private let currentUserIDStore: any CurrentUserIDStoring

    // MARK: - Initialization

    init(
        authenticationService: any AuthenticationService,
        currentUserIDStore: any CurrentUserIDStoring
    ) {
        self.authenticationService = authenticationService
        self.currentUserIDStore = currentUserIDStore
    }

    // MARK: - Session

    /// Restores the SDK-managed session before deciding which application surface to show.
    func restoreSession() async {
        sessionState = .checking

        do {
            if let account = try await authenticationService.currentAccount() {
                await currentUserIDStore.setCurrentUserID(account.id)
                sessionState = .authenticated(account)
            } else {
                await currentUserIDStore.clearCurrentUserID()
                sessionState = .signedOut
            }
        } catch {
            sessionState = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        guard case .authenticated = sessionState else { return }

        sessionState = .checking

        do {
            try await authenticationService.signOut()
            await currentUserIDStore.clearCurrentUserID()
            email = ""
            password = ""
            errorMessage = nil
            noticeMessage = nil
            sessionState = .signedOut
        } catch {
            sessionState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Submission

    func submit() async {
        guard case .signedOut = sessionState,
              canSubmit else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSubmitting = false }

        do {
            switch mode {
            case .signIn:
                let account = try await authenticationService.signIn(
                    email: normalizedEmail,
                    password: password
                )
                await completeAuthentication(with: account)

            case .signUp:
                let result = try await authenticationService.signUp(
                    email: normalizedEmail,
                    password: password
                )
                await handleRegistration(result)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleRegistration(_ result: RegistrationResult) async {
        switch result {
        case .authenticated(let account):
            await completeAuthentication(with: account)

        case .emailConfirmationRequired:
            password = ""
            mode = .signIn
            noticeMessage = "Check your email to confirm the account, then sign in."
        }
    }

    private func completeAuthentication(with account: AuthenticatedAccount) async {
        await currentUserIDStore.setCurrentUserID(account.id)
        password = ""
        sessionState = .authenticated(account)
    }
}
