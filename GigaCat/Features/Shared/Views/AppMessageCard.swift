import SwiftUI

struct AppMessageCard<Accessory: View>: View {
    let title: String
    let message: String
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        message: String,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            accessory()

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColor.border, lineWidth: 1)
        }
    }
}
