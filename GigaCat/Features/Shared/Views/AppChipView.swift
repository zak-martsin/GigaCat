import SwiftUI

struct AppChipView: View {
    let title: String
    let isSelected: Bool
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
    }

    private var backgroundStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(AppColor.textPrimary) : AnyShapeStyle(AppColor.surface)
    }

    private var chipContent: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AppColor.surface : AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .background(backgroundStyle, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? AppColor.textPrimary : AppColor.border, lineWidth: 1)
            }
    }
}
