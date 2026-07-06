import SwiftUI

enum HeaderAction: Hashable {
    case search
    case profile
    case add
    case more

    var iconName: String {
        switch self {
        case .search:
            "magnifyingglass"
        case .profile:
            "person"
        case .add:
            "plus"
        case .more:
            "ellipsis"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .search:
            "Search"
        case .profile:
            "Profile"
        case .add:
            "Add"
        case .more:
            "More"
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
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppSpacing.sm) {
                ForEach(actions, id: \.self) { action in
                    HeaderActionButton(action: action) {
                        onAction(action)
                    }
                }
            }
        }
    }
}

private struct HeaderActionButton: View {
    let action: HeaderAction
    let handler: () -> Void

    var body: some View {
        Button(action: handler) {
            Image(systemName: action.iconName)
                .font(.system(size: AppIconSize.headerAction, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: AppControlSize.headerActionButton, height: AppControlSize.headerActionButton)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(action.accessibilityLabel)
    }
}
