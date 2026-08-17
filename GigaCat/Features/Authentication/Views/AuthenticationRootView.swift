import SwiftUI

struct AuthenticationRootView<Factory: RepositoryFactory>: View {
    @State private var viewModel: AuthenticationViewModel
    @State private var isPasswordRecoveryNoticePresented = false
    private let repositoryFactory: Factory

    init(
        authenticationService: any AuthenticationService,
        currentUserIDStore: any CurrentUserIDStoring,
        repositoryFactory: Factory
    ) {
        _viewModel = State(
            initialValue: AuthenticationViewModel(
                authenticationService: authenticationService,
                currentUserIDStore: currentUserIDStore
            )
        )
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
}
