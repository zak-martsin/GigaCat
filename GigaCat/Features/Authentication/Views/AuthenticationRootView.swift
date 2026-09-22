import SwiftUI

struct AuthenticationRootView<Factory: RepositoryFactory>: View {
    @State private var viewModel: AuthenticationViewModel
    @State private var isPasswordRecoveryPresented = false
    private let repositoryFactory: Factory
    private let profileBootstrapper: any ProfileBootstrapping
    private let syncCoordinator: any SyncCoordinating
    private let systemCatalogSynchronizer: any SystemCatalogSyncing
    private let profileSyncRecoveryService: any ProfileSyncRecovering

    init(
        authenticationService: any AuthenticationService,
        currentUserIDStore: any CurrentUserIDStoring,
        profileBootstrapper: any ProfileBootstrapping,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        profileSyncRecoveryService: any ProfileSyncRecovering,
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
        self.profileBootstrapper = profileBootstrapper
        self.syncCoordinator = syncCoordinator
        self.systemCatalogSynchronizer = systemCatalogSynchronizer
        self.profileSyncRecoveryService = profileSyncRecoveryService
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
                        viewModel.beginPasswordRecovery()
                        isPasswordRecoveryPresented = true
                    },
                    onContinueWithApple: {}
                )

            case .authenticated(let account):
                ContentView(
                    repositoryFactory: repositoryFactory,
                    userID: account.id,
                    syncCoordinator: syncCoordinator,
                    systemCatalogSynchronizer: systemCatalogSynchronizer,
                    profileBootstrapper: profileBootstrapper,
                    profileSyncRecoveryService: profileSyncRecoveryService,
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
        .task {
            await viewModel.observeRefreshedSessions()
        }
        .onOpenURL { url in
            guard url.scheme == "com.zakmartsin.gigacat" else {
                return
            }

            switch url.host {
            case "auth-callback":
                Task {
                    await viewModel.handleCallback(url)
                }

            case "password-recovery":
                isPasswordRecoveryPresented = true
                Task {
                    await viewModel.handlePasswordRecoveryCallback(url)
                }

            default:
                break
            }
        }
        .onChange(of: viewModel.sessionState) { _, newState in
            guard case .authenticated = newState else { return }
            isPasswordRecoveryPresented = false
        }
        .sheet(isPresented: $isPasswordRecoveryPresented) {
            PasswordRecoveryView(viewModel: viewModel)
        }
    }

    private func signOut() {
        Task {
            await viewModel.signOut()
        }
    }

}
