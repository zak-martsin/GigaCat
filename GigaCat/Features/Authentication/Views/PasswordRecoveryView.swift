import SwiftUI

struct PasswordRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AuthenticationViewModel
    @State private var newPassword = ""
    @State private var passwordConfirmation = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    AuthenticationBrandHeaderView()

                    if viewModel.passwordRecoveryState == .readyForNewPassword {
                        newPasswordForm
                    } else {
                        recoveryEmailForm
                    }

                    feedback
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Password Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.passwordRecoveryState != .readyForNewPassword {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(
            viewModel.passwordRecoveryState == .readyForNewPassword
        )
    }

    private var recoveryEmailForm: some View {
        VStack(spacing: AppSpacing.lg) {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .submitLabel(.send)
                .onSubmit(requestRecovery)

            actionButton(
                title: viewModel.passwordRecoveryState == .emailSent
                    ? "Send Again"
                    : "Send Reset Link",
                isDisabled: !viewModel.canRequestPasswordRecovery,
                action: requestRecovery
            )
        }
        .padding(AppSpacing.lg)
        .textFieldStyle(.roundedBorder)
    }

    private var newPasswordForm: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)

                SecureField("Confirm New Password", text: $passwordConfirmation)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .onSubmit(updatePassword)
            }

            if passwordsDoNotMatch {
                Text("Passwords do not match.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actionButton(
                title: "Update Password",
                isDisabled: !canUpdatePassword,
                action: updatePassword
            )
        }
        .padding(AppSpacing.lg)
        .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var feedback: some View {
        if viewModel.passwordRecoveryState == .emailSent,
           let noticeMessage = viewModel.noticeMessage {
            Label(noticeMessage, systemImage: "envelope.badge")
                .font(.subheadline)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .background(
                    AppColor.success.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppRadius.md)
                )
        }

        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .background(
                    Color.red.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: AppRadius.md)
                )
        }
    }

    private func actionButton(
        title: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if viewModel.isSubmitting {
                    SwiftUI.ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.buttonHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(AppColor.accent, in: Capsule())
        .opacity(isDisabled ? 0.35 : 1)
        .disabled(isDisabled)
    }

    private var passwordsDoNotMatch: Bool {
        !passwordConfirmation.isEmpty && newPassword != passwordConfirmation
    }

    private var canUpdatePassword: Bool {
        !newPassword.isEmpty
            && newPassword == passwordConfirmation
            && !viewModel.isSubmitting
    }

    private func requestRecovery() {
        guard viewModel.canRequestPasswordRecovery else { return }

        Task {
            await viewModel.requestPasswordRecovery()
        }
    }

    private func updatePassword() {
        guard canUpdatePassword else { return }

        Task {
            await viewModel.updatePassword(newPassword)
        }
    }
}

#if DEBUG
@MainActor
private struct PasswordRecoveryPreviewHost: View {
    enum Scenario {
        case requestLink
        case newPassword
    }

    @State private var viewModel = AuthenticationPreviewFactory.makeViewModel(
        email: "athlete@example.com"
    )
    let scenario: Scenario

    var body: some View {
        PasswordRecoveryView(viewModel: viewModel)
            .task {
                await viewModel.restoreSession()

                guard scenario == .newPassword,
                      let callbackURL = URL(
                        string: "com.zakmartsin.gigacat://password-recovery?code=preview"
                      ) else {
                    return
                }

                await viewModel.handlePasswordRecoveryCallback(callbackURL)
            }
    }
}

#Preview("Password Recovery") {
    PasswordRecoveryPreviewHost(scenario: .requestLink)
}

#Preview("New Password") {
    PasswordRecoveryPreviewHost(scenario: .newPassword)
}
#endif
