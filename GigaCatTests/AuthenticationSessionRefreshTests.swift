import Foundation
import Testing
@testable import GigaCat

@MainActor
struct AuthenticationSessionRefreshTests {
    @Test
    func renewedSessionResumesOnlyTheCurrentAccount() async {
        let account = AuthenticatedAccount(id: UUID(), email: "user@example.com")
        let refreshes = AsyncStream<UUID>.makeStream()
        let service = AuthenticationServiceStub(
            currentAccount: account,
            refreshedSessions: refreshes.stream
        )
        let coordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: coordinator
        )
        await viewModel.restoreSession()

        let observer = Task { await viewModel.observeRefreshedSessions() }
        refreshes.continuation.yield(UUID())
        refreshes.continuation.yield(account.id)
        refreshes.continuation.finish()
        await observer.value

        #expect(coordinator.activatedUserIDs == [account.id, account.id])
    }

    @Test
    func renewedSessionAfterSignOutDoesNotRestartOldWorker() async {
        let account = AuthenticatedAccount(id: UUID(), email: "user@example.com")
        let refreshes = AsyncStream<UUID>.makeStream()
        let service = AuthenticationServiceStub(
            currentAccount: account,
            refreshedSessions: refreshes.stream
        )
        let coordinator = SyncCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            authenticationService: service,
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: coordinator
        )
        await viewModel.restoreSession()
        await viewModel.signOut()

        let observer = Task { await viewModel.observeRefreshedSessions() }
        refreshes.continuation.yield(account.id)
        refreshes.continuation.finish()
        await observer.value

        #expect(coordinator.activatedUserIDs == [account.id])
    }
}
