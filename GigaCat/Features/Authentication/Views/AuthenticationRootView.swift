import SwiftUI

struct AuthenticationRootView<Factory: RepositoryFactory>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: AuthenticationViewModel
    @State private var isPasswordRecoveryNoticePresented = false
    private let repositoryFactory: Factory
    private let syncCoordinator: any SyncCoordinating
    private let systemCatalogSynchronizer: any SystemCatalogSyncing

    init(
        authenticationService: any AuthenticationService,
        currentUserIDStore: any CurrentUserIDStoring,
        profileBootstrapper: any ProfileBootstrapping,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        repositoryFactory: Factory
    ) {
        _viewModel = State(
            initialValue: AuthenticationViewModel(
                authenticationService: authenticationService,
                currentUserIDStore: currentUserIDStore,
                profileBootstrapper: profileBootstrapper,
                syncCoordinator: syncCoordinator
            )
        )
        self.syncCoordinator = syncCoordinator
        self.systemCatalogSynchronizer = systemCatalogSynchronizer
        self.repositoryFactory = repositoryFactory
    }

    var body: some View {
        Group {
            switch viewModel.sessionState {
            case .checking:
                SwiftUI.ProgressView("Checking session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.background.ignoresSafeArea())

            case .signedOut:
                AuthenticationView(
                    viewModel: viewModel,
                    onForgotPassword: {
                        isPasswordRecoveryNoticePresented = true
                    }
                )

            case .authenticated:
                ContentView(
                    repositoryFactory: repositoryFactory,
                    syncCoordinator: syncCoordinator,
                    systemCatalogSynchronizer: systemCatalogSynchronizer,
                    onSignOut: signOut
                )

            case .failed(let message):
                ContentUnavailableView {
                    Label("Session unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await viewModel.restoreSession()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            guard case .checking = viewModel.sessionState else { return }
            await viewModel.restoreSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, authenticatedUserID != nil else { return }
            syncCoordinator.requestSync()
        }
        .alert(
            "Password recovery",
            isPresented: $isPasswordRecoveryNoticePresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password recovery will be added after the core authentication flow.")
        }
    }

    private func signOut() {
        Task {
            await viewModel.signOut()
        }
    }

    private var authenticatedUserID: UUID? {
        guard case .authenticated(let account) = viewModel.sessionState else {
            return nil
        }
        return account.id
    }
}
