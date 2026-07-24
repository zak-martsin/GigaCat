import SwiftUI

enum AppCardStyle {
    case standard
    case selected
    case tinted
    case elevated
}

struct AppCardModifier: ViewModifier {
    private static let selectedScale: CGFloat = 1.02

    let style: AppCardStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(backgroundStyle)
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    y: shadowOffsetY
                )
                .overlay {
                    if style == .selected {
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(AppColor.border, lineWidth: 2)
                    }
                }
            }
            .scaleEffect(
                style == .selected ? Self.selectedScale : 1
            )
            .animation(.snappy, value: style == .selected)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .standard, .selected, .elevated:
            AnyShapeStyle(AppColor.surface)
        case .tinted:
            AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.surface, AppColor.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var shadowColor: Color {
        switch style {
        case .standard, .tinted:
            AppShadow.cardColor
        case .selected:
            AppShadow.selectedColor
        case .elevated:
            AppShadow.elevatedColor
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .standard, .tinted:
            AppShadow.cardRadius
        case .selected:
            AppShadow.selectedRadius
        case .elevated:
            AppShadow.elevatedRadius
        }
    }

    private var shadowOffsetY: CGFloat {
        switch style {
        case .standard, .tinted:
            AppShadow.cardOffsetY
        case .selected:
            AppShadow.selectedOffsetY
        case .elevated:
            AppShadow.elevatedOffsetY
        }
    }
}

extension View {
    func appCardStyle(
        _ style: AppCardStyle = .standard,
        cornerRadius: CGFloat = AppRadius.lg
    ) -> some View {
        modifier(
            AppCardModifier(
                style: style,
                cornerRadius: cornerRadius
            )
        )
    }
}
