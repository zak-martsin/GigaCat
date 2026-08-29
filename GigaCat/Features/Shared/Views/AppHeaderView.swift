import SwiftUI

enum HeaderAction: Hashable {
    case profile

    var iconName: String {
        switch self {
        case .profile:
            "person"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .profile:
            "Profile"
        }
    }
}

struct AppHeaderView: View {
    let title: String
    let actions: [HeaderAction]
    let onAction: (HeaderAction) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: AppSpacing.md)

            HStack(spacing: AppSpacing.sm) {
                ForEach(actions, id: \.self) { action in
                    HeaderActionButton(action: action) {
                        onAction(action)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: AppControlSize.headerHeight,
            alignment: .leading
        )
    }
}

private struct HeaderActionButton: View {
    let action: HeaderAction
    let handler: () -> Void

    var body: some View {
        Button(action: handler) {
            Image(systemName: action.iconName)
                .font(.system(size: AppIconSize.iconButton, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: AppControlSize.iconButton, height: AppControlSize.iconButton)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(action.accessibilityLabel)
    }
}
