import SwiftUI

struct PlaceholderFeatureView: View {
    let headerTitle: String
    let eyebrow: String
    let title: String
    let message: String
    let symbolName: String
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    FeatureHeroCard(
                        eyebrow: eyebrow,
                        title: title,
                        message: message
                    )

                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: symbolName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(AppColor.border, lineWidth: 1)
                            }

                        Text("Native iOS 26 shell first, feature-specific data and actions next.")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(AppSpacing.lg)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColor.border, lineWidth: 1)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private var header: some View {
        AppHeaderView(
            title: headerTitle,
            actions: [.profile],
            onAction: handleHeaderAction
        )
    }

    private func handleHeaderAction(_ action: HeaderAction) {
        onHeaderAction(action)
    }
}
