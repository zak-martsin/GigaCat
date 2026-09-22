import SwiftUI

struct AuthenticationView: View {
    @Bindable var viewModel: AuthenticationViewModel
    let onForgotPassword: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                header
                credentialsForm
                feedback
                submitButton
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xxl)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColor.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: AppIconSize.authenticationLogo, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: AppControlSize.authenticationLogo,
                    height: AppControlSize.authenticationLogo
                )
                .background(AppColor.accent, in: RoundedRectangle(cornerRadius: AppRadius.lg))

            Text("GigaCat")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text("Your workouts stay ready on every training day.")
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var credentialsForm: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.next)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }

            if viewModel.mode == .signIn {
                authenticationPrompt(
                    message: "Forgot your password?",
                    actionTitle: "Reset it",
                    action: onForgotPassword
                )
            }

            authenticationPrompt(
                message: modePromptMessage,
                actionTitle: modePromptActionTitle,
                action: switchMode
            )
        }
        .padding(AppSpacing.lg)
        .textFieldStyle(.roundedBorder)
        .appCardStyle()
    }

    private func authenticationPrompt(
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(message)
                .foregroundStyle(AppColor.textSecondary)

            Button(actionTitle, action: action)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.textPrimary)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var feedback: some View {
        if let noticeMessage = viewModel.noticeMessage {
            Label(noticeMessage, systemImage: "envelope.badge")
                .font(.subheadline)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .background(AppColor.success.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.md))
        }

        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if viewModel.isSubmitting {
                    SwiftUI.ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.mode.title)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.buttonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColor.accent)
        .disabled(!viewModel.canSubmit)
    }

    private func submit() {
        Task {
            await viewModel.submit()
        }
    }

    private var modePromptMessage: String {
        switch viewModel.mode {
        case .signIn:
            "Don’t have an account?"
        case .signUp:
            "Already have an account?"
        }
    }

    private var modePromptActionTitle: String {
        switch viewModel.mode {
        case .signIn:
            "Sign Up"
        case .signUp:
            "Sign In"
        }
    }

    private func switchMode() {
        viewModel.mode = viewModel.mode == .signIn ? .signUp : .signIn
    }
}

#if DEBUG
@MainActor
private struct AuthenticationPreviewHost: View {
    @State private var viewModel: AuthenticationViewModel

    init(mode: AuthenticationMode) {
        _viewModel = State(
            initialValue: AuthenticationPreviewFactory.makeViewModel(mode: mode)
        )
    }

    var body: some View {
        AuthenticationView(
            viewModel: viewModel,
            onForgotPassword: {}
        )
        .task {
            await viewModel.restoreSession()
        }
    }
}

#Preview("Sign In") {
    AuthenticationPreviewHost(mode: .signIn)
}

#Preview("Sign Up") {
    AuthenticationPreviewHost(mode: .signUp)
}
#endif
