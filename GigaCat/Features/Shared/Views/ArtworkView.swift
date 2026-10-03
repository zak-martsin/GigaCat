import ImageIO
import SwiftUI
import UIKit

enum ArtworkContentMode: Hashable {
    case fill
    case fit
}

/// Displays cached catalog artwork while preserving the shared placeholder.
struct ArtworkView<Overlay: View>: View {
    let fileURL: URL?
    let contentMode: ArtworkContentMode
    let cornerRadius: CGFloat
    let height: CGFloat?
    let width: CGFloat?
    @ViewBuilder let overlayContent: () -> Overlay

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    init(
        fileURL: URL?,
        contentMode: ArtworkContentMode,
        cornerRadius: CGFloat = AppRadius.lg,
        height: CGFloat? = nil,
        width: CGFloat? = nil,
        @ViewBuilder overlayContent: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.fileURL = fileURL
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.height = height
        self.width = width
        self.overlayContent = overlayContent
    }

    var body: some View {
        ArtworkPlaceholderView(
            cornerRadius: cornerRadius,
            height: height,
            width: width
        )
        .opacity(image == nil ? 1 : 0)
        .overlay {
            GeometryReader { geometry in
                Color.clear
                    .overlay {
                        artwork(in: geometry.size)
                    }
                    .task(id: loadRequest(for: geometry.size)) {
                        await loadImage(maximumPointSize: geometry.size)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            overlayContent()
        }
    }

    @ViewBuilder
    private func artwork(in size: CGSize) -> some View {
        if let image {
            switch contentMode {
            case .fill:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .accessibilityHidden(true)
            case .fit:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .accessibilityHidden(true)
            }
        }
    }

    private func loadRequest(for size: CGSize) -> ArtworkImageLoadRequest {
        ArtworkImageLoadRequest(
            fileURL: fileURL,
            maximumPixelSize: maximumPixelSize(for: size)
        )
    }

    private func loadImage(maximumPointSize: CGSize) async {
        image = nil
        guard let fileURL else { return }

        let pixelSize = maximumPixelSize(for: maximumPointSize)
        let cgImage = await Task.detached(priority: .utility) {
            Self.downsampledImage(
                at: fileURL,
                maximumPixelSize: pixelSize
            )
        }.value

        guard !Task.isCancelled,
              fileURL == self.fileURL,
              let cgImage else {
            return
        }
        image = UIImage(cgImage: cgImage)
    }

    private func maximumPixelSize(for size: CGSize) -> Int {
        max(1, Int(ceil(max(size.width, size.height) * displayScale)))
    }

    nonisolated private static func downsampledImage(
        at fileURL: URL,
        maximumPixelSize: Int
    ) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

private struct ArtworkImageLoadRequest: Hashable {
    let fileURL: URL?
    let maximumPixelSize: Int
}
