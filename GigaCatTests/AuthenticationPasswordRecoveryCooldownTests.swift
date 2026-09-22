import Foundation
import Testing
@testable import GigaCat

@MainActor
struct PasswordRecoveryCooldownTests {
    @Test
    func failedRequestDoesNotStartCooldown() async {
        let viewModel = AuthenticationViewModel(
            authenticationService: AuthenticationServiceStub(
                passwordRecoveryError: .serviceUnavailable
            ),
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: ProfileBootstrapperSpy(),
            syncCoordinator: SyncCoordinatorSpy()
        )
        await viewModel.restoreSession()
        viewModel.email = "user@example.com"

        await viewModel.requestPasswordRecovery()

        #expect(viewModel.passwordRecoveryCooldownRemaining == 0)
        #expect(viewModel.canRequestPasswordRecovery)
        #expect(
            viewModel.errorMessage
                == AuthenticationError.serviceUnavailable.localizedDescription
        )
    }
}
