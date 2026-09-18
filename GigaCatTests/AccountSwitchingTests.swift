import Foundation
import Testing
@testable import GigaCat

@MainActor
struct AccountSwitchingTests {

    @Test
    func signInStopsPreviousSyncBeforeInstallingNewUser() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "new-user@example.com"
        )
        let recorder = AccountTransitionRecorder()
        let viewModel = makeViewModel(
            service: AccountTransitionAuthenticationService(
                signInAccount: account,
                recorder: recorder
            ),
            recorder: recorder
        )
        await viewModel.restoreSession()
        await recorder.reset()
        viewModel.email = account.email ?? ""
        viewModel.password = "password"

        await viewModel.submit()

        #expect(
            await recorder.recordedEvents() == [
                "authenticate:\(account.id)",
                "deactivate",
                "set:\(account.id)",
                "bootstrap:\(account.id)",
                "activate:\(account.id)"
            ]
        )
        #expect(viewModel.sessionState == .authenticated(account))
    }

    @Test
    func signOutStopsSyncBeforeRemovingSupabaseSessionAndLocalUser() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let recorder = AccountTransitionRecorder()
        let viewModel = makeViewModel(
            service: AccountTransitionAuthenticationService(
                currentAccount: account,
                recorder: recorder
            ),
            recorder: recorder
        )
        await viewModel.restoreSession()
        await recorder.reset()

        await viewModel.signOut()

        #expect(
            await recorder.recordedEvents() == [
                "deactivate",
                "signOutSession",
                "clear"
            ]
        )
        #expect(viewModel.sessionState == .signedOut)
    }

    @Test
    func failedSupabaseSignOutRestoresSyncForCurrentAccount() async {
        let account = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        )
        let recorder = AccountTransitionRecorder()
        let currentUserStore = AccountTransitionCurrentUserStore(
            recorder: recorder
        )
        let viewModel = makeViewModel(
            service: AccountTransitionAuthenticationService(
                currentAccount: account,
                signOutError: .serviceUnavailable,
                recorder: recorder
            ),
            currentUserStore: currentUserStore,
            recorder: recorder
        )
        await viewModel.restoreSession()
        await recorder.reset()

        await viewModel.signOut()

        #expect(
            await recorder.recordedEvents() == [
                "deactivate",
                "signOutSession",
                "activate:\(account.id)"
            ]
        )
        #expect(await currentUserStore.currentUserID() == account.id)
        guard case .failed = viewModel.sessionState else {
            Issue.record("Expected failed state after Supabase sign-out error")
            return
        }
    }

    private func makeViewModel(
        service: AccountTransitionAuthenticationService,
        currentUserStore: AccountTransitionCurrentUserStore? = nil,
        recorder: AccountTransitionRecorder
    ) -> AuthenticationViewModel {
        AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: currentUserStore
                ?? AccountTransitionCurrentUserStore(recorder: recorder),
            profileBootstrapper: AccountTransitionProfileBootstrapper(
                recorder: recorder
            ),
            syncCoordinator: AccountTransitionSyncCoordinator(
                recorder: recorder
            )
        )
    }
}

private actor AccountTransitionRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func reset() {
        events.removeAll()
    }

    func recordedEvents() -> [String] {
        events
    }
}

private actor AccountTransitionCurrentUserStore: CurrentUserIDStoring {
    private var userID: UUID?
    private let recorder: AccountTransitionRecorder

    init(recorder: AccountTransitionRecorder) {
        self.recorder = recorder
    }

    func currentUserID() -> UUID? {
        userID
    }

    func setCurrentUserID(_ userID: UUID) async {
        self.userID = userID
        await recorder.record("set:\(userID)")
    }

    func clearCurrentUserID() async {
        userID = nil
        await recorder.record("clear")
    }
}

@MainActor
private final class AccountTransitionProfileBootstrapper: ProfileBootstrapping {
    private let recorder: AccountTransitionRecorder

    init(recorder: AccountTransitionRecorder) {
        self.recorder = recorder
    }

    func bootstrapProfile(for userID: UUID) async throws {
        await recorder.record("bootstrap:\(userID)")
    }

    func refreshProfile(for _: UUID) -> Bool {
        false
    }
}

@MainActor
private final class AccountTransitionSyncCoordinator: SyncCoordinating {
    private let recorder: AccountTransitionRecorder

    init(recorder: AccountTransitionRecorder) {
        self.recorder = recorder
    }

    func activate(for userID: UUID) async {
        await recorder.record("activate:\(userID)")
    }

    func deactivate() async {
        await recorder.record("deactivate")
    }

    func requestSync() async {}
}

private actor AccountTransitionAuthenticationService: AuthenticationService {
    private let currentAccountValue: AuthenticatedAccount?
    private let signInAccount: AuthenticatedAccount
    private let signOutError: AuthenticationError?
    private let recorder: AccountTransitionRecorder

    init(
        currentAccount: AuthenticatedAccount? = nil,
        signInAccount: AuthenticatedAccount = AuthenticatedAccount(
            id: UUID(),
            email: "user@example.com"
        ),
        signOutError: AuthenticationError? = nil,
        recorder: AccountTransitionRecorder
    ) {
        currentAccountValue = currentAccount
        self.signInAccount = signInAccount
        self.signOutError = signOutError
        self.recorder = recorder
    }

    func currentAccount() -> AuthenticatedAccount? {
        currentAccountValue
    }

    nonisolated func refreshedSessionUserIDs() -> AsyncStream<UUID> {
        AsyncStream { $0.finish() }
    }

    func signUp(email _: String, password _: String) -> RegistrationResult {
        .emailConfirmationRequired
    }

    func signIn(email _: String, password _: String) async -> AuthenticatedAccount {
        await recorder.record("authenticate:\(signInAccount.id)")
        return signInAccount
    }

    func handleCallback(_: URL) -> AuthenticatedAccount {
        signInAccount
    }

    func requestPasswordRecovery(email _: String) {}

    func preparePasswordRecovery(from _: URL) {}

    func updatePassword(_: String) -> AuthenticatedAccount {
        signInAccount
    }

    func signOut() async throws {
        await recorder.record("signOutSession")
        if let signOutError {
            throw signOutError
        }
    }
}
