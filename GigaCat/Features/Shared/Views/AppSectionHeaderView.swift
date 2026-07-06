import SwiftUI

struct AppSectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}
