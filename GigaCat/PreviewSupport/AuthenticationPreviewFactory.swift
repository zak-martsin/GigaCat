#if DEBUG
import Foundation

/// Builds authentication view models that are isolated from persistence and the network.
@MainActor
enum AuthenticationPreviewFactory {
    static func makeViewModel(
        mode: AuthenticationMode = .signIn,
        email: String = "",
        password: String = ""
    ) -> AuthenticationViewModel {
        let viewModel = AuthenticationViewModel(
            authenticationService: MockAuthenticationService(),
            currentUserIDStore: CurrentUserContext(),
            profileBootstrapper: PreviewProfileBootstrapper(),
            syncCoordinator: PreviewSyncCoordinator()
        )
        viewModel.mode = mode
        viewModel.email = email
        viewModel.password = password
        return viewModel
    }
}

@MainActor
private final class PreviewProfileBootstrapper: ProfileBootstrapping {
    func bootstrapProfile(for _: UUID) async throws {}

    func refreshProfile(for _: UUID) async throws -> Bool {
        false
    }
}

@MainActor
private final class PreviewSyncCoordinator: SyncCoordinating {
    func activate(for _: UUID) async {}
    func deactivate() async {}
    func requestSync() async {}
}
#endif
