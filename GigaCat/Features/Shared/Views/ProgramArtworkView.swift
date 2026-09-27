import SwiftUI
import UIKit

/// Displays a cached program image while preserving the shared artwork placeholder.
struct ProgramArtworkView<Overlay: View>: View {
    let fileURL: URL?
    let cornerRadius: CGFloat
    let height: CGFloat?
    let width: CGFloat?
    @ViewBuilder let overlayContent: () -> Overlay

    @State private var image: UIImage?

    init(
        fileURL: URL?,
        cornerRadius: CGFloat = AppRadius.lg,
        height: CGFloat? = nil,
        width: CGFloat? = nil,
        @ViewBuilder overlayContent: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.fileURL = fileURL
        self.cornerRadius = cornerRadius
        self.height = height
        self.width = width
        self.overlayContent = overlayContent
    }

    var body: some View {
        ProgramArtworkPlaceholderView(
            cornerRadius: cornerRadius,
            height: height,
            width: width
        )
        .overlay {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            overlayContent()
        }
        .task(id: fileURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = nil
        guard let fileURL else { return }

        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        }.value

        guard !Task.isCancelled,
              fileURL == self.fileURL,
              let data else {
            return
        }
        image = UIImage(data: data)
    }
}
