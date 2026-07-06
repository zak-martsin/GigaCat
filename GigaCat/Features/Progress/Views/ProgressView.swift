import SwiftUI

struct ProgressView: View {
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        PlaceholderFeatureView(
            headerTitle: "Progress",
            eyebrow: "Progress",
            title: "Charts, body weight and trends will live here.",
            message: "This tab is ready for the next layer once we introduce real progress state and chart data.",
            symbolName: AppTab.progress.systemImage,
            onHeaderAction: onHeaderAction
        )
    }
}
