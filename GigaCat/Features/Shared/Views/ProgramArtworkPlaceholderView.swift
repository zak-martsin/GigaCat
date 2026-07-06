import SwiftUI

struct ProgramArtworkPlaceholderView<Overlay: View>: View {
    let cornerRadius: CGFloat
    let height: CGFloat?
    let width: CGFloat?
    @ViewBuilder let overlayContent: () -> Overlay

    init(
        cornerRadius: CGFloat = AppRadius.lg,
        height: CGFloat? = nil,
        width: CGFloat? = nil,
        @ViewBuilder overlayContent: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.cornerRadius = cornerRadius
        self.height = height
        self.width = width
        self.overlayContent = overlayContent
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        AppColor.textPrimary.opacity(0.94),
                        AppColor.textSecondary.opacity(0.72),
                        AppColor.border.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay {
                overlayContent()
            }
    }
}
