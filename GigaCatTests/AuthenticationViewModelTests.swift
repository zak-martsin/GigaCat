import Foundation
import Testing
@testable import GigaCat

@MainActor
struct AuthenticationViewModelTests {

    @Test
    func restoreSessionShowsAuthenticatedAppForExistingAccount() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let service = AuthenticationServiceStub(currentAccount: account)
        let currentUserContext = CurrentUserContext()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext
        )

        await viewModel.restoreSession()

        #expect(viewModel.sessionState == .authenticated(account))
        #expect(await currentUserContext.currentUserID() == account.id)
    }

    @Test
    func restoreSessionShowsAuthenticationFormWithoutAccount() async {
        let currentUserContext = CurrentUserContext(userID: UUID())
        let viewModel = AuthenticationViewModel(
            authenticationService: AuthenticationServiceStub(),
            currentUserIDStore: currentUserContext
        )

        await viewModel.restoreSession()

        #expect(viewModel.sessionState == .signedOut)
        #expect(await currentUserContext.currentUserID() == nil)
    }

    @Test
    func signInTrimsEmailAndAuthenticatesAccount() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let service = AuthenticationServiceStub(signInAccount: account)
        let currentUserContext = CurrentUserContext()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext
        )
        await viewModel.restoreSession()
        viewModel.email = "  user@example.com  "
        viewModel.password = "password"

        await viewModel.submit()

        #expect(viewModel.sessionState == .authenticated(account))
        #expect(viewModel.password.isEmpty)
        #expect(await service.lastSignInEmail() == "user@example.com")
        #expect(await currentUserContext.currentUserID() == account.id)
    }

    @Test
    func signUpShowsConfirmationNoticeAndReturnsToSignInMode() async {
        let service = AuthenticationServiceStub(
            signUpResult: .emailConfirmationRequired
        )
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: CurrentUserContext()
        )
        await viewModel.restoreSession()
        viewModel.mode = .signUp
        viewModel.email = "user@example.com"
        viewModel.password = "password"

        await viewModel.submit()

        #expect(viewModel.sessionState == .signedOut)
        #expect(viewModel.mode == .signIn)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.noticeMessage != nil)
    }

    @Test
    func submissionFailureKeepsFormVisible() async {
        let service = AuthenticationServiceStub(signInError: .invalidCredentials)
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: CurrentUserContext()
        )
        await viewModel.restoreSession()
        viewModel.email = "user@example.com"
        viewModel.password = "wrong-password"

        await viewModel.submit()

        #expect(viewModel.sessionState == .signedOut)
        #expect(viewModel.errorMessage == AuthenticationError.invalidCredentials.localizedDescription)
        #expect(viewModel.password == "wrong-password")
    }

    @Test
    func signOutClearsSessionAndReturnsToAuthenticationForm() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let service = AuthenticationServiceStub(currentAccount: account)
        let currentUserContext = CurrentUserContext()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext
        )
        await viewModel.restoreSession()
        viewModel.email = "user@example.com"
        viewModel.password = "password"

        await viewModel.signOut()

        #expect(viewModel.sessionState == .signedOut)
        #expect(viewModel.email.isEmpty)
        #expect(viewModel.password.isEmpty)
        #expect(await service.didSignOut())
        #expect(await currentUserContext.currentUserID() == nil)
    }
}

private actor AuthenticationServiceStub: AuthenticationService {
    private let currentAccountValue: AuthenticatedAccount?
    private let currentAccountError: AuthenticationError?
    private let signUpResultValue: RegistrationResult
    private let signUpError: AuthenticationError?
    private let signInAccountValue: AuthenticatedAccount
    private let signInError: AuthenticationError?
    private var receivedSignInEmail: String?
    private var signedOut = false

    init(
        currentAccount: AuthenticatedAccount? = nil,
        currentAccountError: AuthenticationError? = nil,
        signUpResult: RegistrationResult = .emailConfirmationRequired,
        signUpError: AuthenticationError? = nil,
        signInAccount: AuthenticatedAccount = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        ),
        signInError: AuthenticationError? = nil
    ) {
        currentAccountValue = currentAccount
        self.currentAccountError = currentAccountError
        signUpResultValue = signUpResult
        self.signUpError = signUpError
        signInAccountValue = signInAccount
        self.signInError = signInError
    }

    func currentAccount() throws -> AuthenticatedAccount? {
        if let currentAccountError {
            throw currentAccountError
        }
        return currentAccountValue
    }

    func signUp(
        email _: String,
        password _: String
    ) throws -> RegistrationResult {
        if let signUpError {
            throw signUpError
        }
        return signUpResultValue
    }

    func signIn(
        email: String,
        password _: String
    ) throws -> AuthenticatedAccount {
        receivedSignInEmail = email
        if let signInError {
            throw signInError
        }
        return signInAccountValue
    }

    func signOut() {
        signedOut = true
    }

    func lastSignInEmail() -> String? {
        receivedSignInEmail
    }

    func didSignOut() -> Bool {
        signedOut
    }
}
