import SwiftUI

struct ProfileSheetView: View {
    let user: User?
    @ObservedObject var viewModel: ProfileSheetViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Profile")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if let user {
                    profileRow(title: "User ID", value: user.id.uuidString)
                    profileRow(
                        title: "Selected Program ID",
                        value: user.selectedProgramId?.uuidString ?? "No program selected"
                    )
                    profileRow(title: "Created At", value: formatted(user.createdAt))
                    profileRow(title: "Updated At", value: formatted(user.updatedAt))
                } else {
                    Text("User profile is not available yet.")
                        .font(.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                        .appCardStyle()
                }

                if viewModel.isSyncFailureVisible {
                    Label(
                        "Your program change is saved on this device, but could not sync yet.",
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .appCardStyle()
                    .accessibilityIdentifier("profileSyncFailureStatus")
                }

                Spacer(minLength: AppSpacing.lg)

                Button(role: .destructive, action: onSignOut) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppControlSize.buttonHeight)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.background.ignoresSafeArea())
        .task {
            while !Task.isCancelled {
                viewModel.refreshSyncStatus()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            Text(value)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .appCardStyle()
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
