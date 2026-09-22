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

enum PasswordRecoveryState: Equatable {
    case idle
    case emailSent
    case readyForNewPassword
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
    private(set) var passwordRecoveryState: PasswordRecoveryState = .idle
    private(set) var passwordRecoveryCooldownRemaining = 0

    @ObservationIgnored
    private var passwordRecoveryCooldownTask: Task<Void, Never>?

    var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty && !isSubmitting
    }

    var canRequestPasswordRecovery: Bool {
        !normalizedEmail.isEmpty
            && !isSubmitting
            && passwordRecoveryCooldownRemaining == 0
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let authenticationService: any AuthenticationService

    @ObservationIgnored
    private let currentUserIDStore: any CurrentUserIDStoring

    @ObservationIgnored
    private let profileBootstrapper: any ProfileBootstrapping

    @ObservationIgnored
    private let syncCoordinator: any SyncCoordinating

    // MARK: - Initialization

    init(
        authenticationService: any AuthenticationService,
        currentUserIDStore: any CurrentUserIDStoring,
        profileBootstrapper: any ProfileBootstrapping,
        syncCoordinator: any SyncCoordinating
    ) {
        self.authenticationService = authenticationService
        self.currentUserIDStore = currentUserIDStore
        self.profileBootstrapper = profileBootstrapper
        self.syncCoordinator = syncCoordinator
    }

    // MARK: - Session

    /// Resumes a worker paused by auth failure only for the account currently shown in the app.
    func observeRefreshedSessions() async {
        for await userID in authenticationService.refreshedSessionUserIDs() {
            guard case .authenticated(let account) = sessionState,
                  account.id == userID else {
                continue
            }
            await syncCoordinator.activate(for: userID)
        }
    }

    /// Restores the SDK-managed session before deciding which application surface to show.
    func restoreSession() async {
        sessionState = .checking

        do {
            if let account = try await authenticationService.currentAccount() {
                try await completeAuthentication(with: account)
            } else {
                await syncCoordinator.deactivate()
                await currentUserIDStore.clearCurrentUserID()
                sessionState = .signedOut
            }
        } catch {
            sessionState = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        guard case .authenticated(let account) = sessionState else { return }

        sessionState = .checking
        await syncCoordinator.deactivate()

        do {
            try await authenticationService.signOut()
            await currentUserIDStore.clearCurrentUserID()
            email = ""
            password = ""
            errorMessage = nil
            noticeMessage = nil
            passwordRecoveryState = .idle
            resetPasswordRecoveryCooldown()
            sessionState = .signedOut
        } catch {
            await syncCoordinator.activate(for: account.id)
            sessionState = .failed(error.localizedDescription)
        }
    }

    func handleCallback(_ url: URL) async {
        sessionState = .checking
        errorMessage = nil
        noticeMessage = nil

        do {
            let account = try await authenticationService.handleCallback(url)
            try await completeAuthentication(with: account)
        } catch {
            sessionState = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    /// Requests a recovery email without revealing whether the account exists.
    func requestPasswordRecovery() async {
        guard case .signedOut = sessionState,
              canRequestPasswordRecovery else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSubmitting = false }

        do {
            try await authenticationService.requestPasswordRecovery(
                email: normalizedEmail
            )
            passwordRecoveryState = .emailSent
            noticeMessage = "If an account exists for this email, a password reset link has been sent."
            startPasswordRecoveryCooldown()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginPasswordRecovery() {
        guard case .signedOut = sessionState else { return }

        passwordRecoveryState = .idle
        errorMessage = nil
        noticeMessage = nil
    }

    /// Prepares the SDK session used by the future new-password screen.
    func handlePasswordRecoveryCallback(_ url: URL) async {
        sessionState = .checking
        errorMessage = nil
        noticeMessage = nil
        resetPasswordRecoveryCooldown()

        do {
            try await authenticationService.preparePasswordRecovery(from: url)
            passwordRecoveryState = .readyForNewPassword
            sessionState = .signedOut
        } catch {
            passwordRecoveryState = .idle
            sessionState = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    /// Updates the password through the recovery session and completes normal authentication.
    func updatePassword(_ newPassword: String) async {
        guard passwordRecoveryState == .readyForNewPassword,
              !newPassword.isEmpty,
              !isSubmitting else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSubmitting = false }

        do {
            let account = try await authenticationService.updatePassword(
                newPassword
            )
            try await completeAuthentication(with: account)
            passwordRecoveryState = .idle
        } catch {
            errorMessage = error.localizedDescription
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
                try await completeAuthentication(with: account)

            case .signUp:
                let result = try await authenticationService.signUp(
                    email: normalizedEmail,
                    password: password
                )
                try await handleRegistration(result)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Prevents repeated recovery requests while keeping the countdown accurate after suspension.
    private func startPasswordRecoveryCooldown() {
        passwordRecoveryCooldownTask?.cancel()

        let duration: TimeInterval = 45
        let deadline = Date().addingTimeInterval(duration)
        passwordRecoveryCooldownRemaining = Int(duration)

        passwordRecoveryCooldownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }

                let remaining = max(
                    0,
                    Int(ceil(deadline.timeIntervalSinceNow))
                )
                self?.passwordRecoveryCooldownRemaining = remaining

                guard remaining > 0 else { return }

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    private func resetPasswordRecoveryCooldown() {
        passwordRecoveryCooldownTask?.cancel()
        passwordRecoveryCooldownTask = nil
        passwordRecoveryCooldownRemaining = 0
    }

    private func handleRegistration(_ result: RegistrationResult) async throws {
        switch result {
        case .authenticated(let account):
            try await completeAuthentication(with: account)

        case .emailConfirmationRequired:
            password = ""
            mode = .signIn
            noticeMessage = "Check your email to confirm the account, then sign in."
        }
    }

    private func completeAuthentication(with account: AuthenticatedAccount) async throws {
        await syncCoordinator.deactivate()
        await currentUserIDStore.setCurrentUserID(account.id)

        do {
            try await profileBootstrapper.bootstrapProfile(for: account.id)
        } catch {
            await currentUserIDStore.clearCurrentUserID()
            throw error
        }

        await syncCoordinator.activate(for: account.id)
        password = ""
        sessionState = .authenticated(account)
    }
}
