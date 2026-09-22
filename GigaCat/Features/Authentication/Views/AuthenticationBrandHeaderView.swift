import SwiftUI

/// Displays the shared GigaCat branding used across authentication flows.
struct AuthenticationBrandHeaderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image("blackGigaCat")
                .resizable()
                .scaledToFit()
                .frame(
                    width: AppControlSize.authenticationBrandLockup,
                    height: AppControlSize.authenticationBrandLockup
                )
                .accessibilityLabel("GigaCat")

            Text("Your workouts stay ready on every training day.")
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
