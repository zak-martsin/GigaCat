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
        let profileBootstrapper = ProfileBootstrapperSpy()
        let syncCoordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext,
            profileBootstrapper: profileBootstrapper,
            syncCoordinator: syncCoordinator
        )

        await viewModel.restoreSession()

        #expect(viewModel.sessionState == .authenticated(account))
        #expect(await currentUserContext.currentUserID() == account.id)
        #expect(profileBootstrapper.receivedUserIDs == [account.id])
        #expect(syncCoordinator.activatedUserIDs == [account.id])
    }

    @Test
    func restoreSessionShowsAuthenticationFormWithoutAccount() async {
        let currentUserContext = CurrentUserContext(userID: UUID())
        let viewModel = AuthenticationViewModel(
            authenticationService: AuthenticationServiceStub(),
            currentUserIDStore: currentUserContext,
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: SyncCoordinatorSpy()
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
        let profileBootstrapper = ProfileBootstrapperSpy()
        let syncCoordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext,
            profileBootstrapper: profileBootstrapper,
            syncCoordinator: syncCoordinator
        )
        await viewModel.restoreSession()
        viewModel.email = "  user@example.com  "
        viewModel.password = "password"

        await viewModel.submit()

        #expect(viewModel.sessionState == .authenticated(account))
        #expect(viewModel.password.isEmpty)
        #expect(await service.lastSignInEmail() == "user@example.com")
        #expect(await currentUserContext.currentUserID() == account.id)
        #expect(profileBootstrapper.receivedUserIDs == [account.id])
        #expect(syncCoordinator.activatedUserIDs == [account.id])
    }

    @Test
    func signUpShowsConfirmationNoticeAndReturnsToSignInMode() async {
        let service = AuthenticationServiceStub(
            signUpResult: .emailConfirmationRequired
        )
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: SyncCoordinatorSpy()
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
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: SyncCoordinatorSpy()
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
    func profileBootstrapFailureDoesNotExposeAuthenticatedFeatures() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let currentUserContext = CurrentUserContext()
        let syncCoordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: AuthenticationServiceStub(signInAccount: account),
            currentUserIDStore: currentUserContext,
            profileBootstrapper: ProfileBootstrapperSpy(error: .failed),
            syncCoordinator: syncCoordinator
        )
        await viewModel.restoreSession()
        let deactivationCountBeforeSubmission = syncCoordinator.deactivationCount
        viewModel.email = "user@example.com"
        viewModel.password = "password"

        await viewModel.submit()

        #expect(viewModel.sessionState == .signedOut)
        #expect(viewModel.errorMessage == ProfileBootstrapTestError.failed.localizedDescription)
        #expect(await currentUserContext.currentUserID() == nil)
        #expect(
            syncCoordinator.deactivationCount
                == deactivationCountBeforeSubmission + 1
        )
    }

    @Test
    func signOutClearsSessionAndReturnsToAuthenticationForm() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let service = AuthenticationServiceStub(currentAccount: account)
        let currentUserContext = CurrentUserContext()
        let syncCoordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserContext,
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: syncCoordinator
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
        #expect(syncCoordinator.deactivationCount == 1)
    }
}

@MainActor
private final class SyncCoordinatorSpy: SyncCoordinating {
    private(set) var activatedUserIDs: [UUID] = []
    private(set) var deactivationCount = 0
    private(set) var requestCount = 0

    func activate(for userID: UUID) {
        activatedUserIDs.append(userID)
    }

    func deactivate() {
        deactivationCount += 1
    }

    func requestSync() {
        requestCount += 1
    }
}

@MainActor
private final class ProfileBootstrapperSpy: ProfileBootstrapping {
    private(set) var receivedUserIDs: [UUID] = []
    private let error: ProfileBootstrapTestError?

    init(error: ProfileBootstrapTestError? = nil) {
        self.error = error
    }

    func bootstrapProfile(for userID: UUID) throws {
        receivedUserIDs.append(userID)

        if let error {
            throw error
        }
    }
}

private enum ProfileBootstrapTestError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Unable to prepare the local profile."
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
