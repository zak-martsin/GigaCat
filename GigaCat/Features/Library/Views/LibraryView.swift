import SwiftUI

struct LibraryView: View {
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        PlaceholderFeatureView(
            headerTitle: "Library",
            eyebrow: "Library",
            title: "Programs and exercise references can expand here.",
            message: "This tab is a clean place for browsing plans once search and program details arrive.",
            symbolName: AppTab.library.systemImage,
            onHeaderAction: onHeaderAction
        )
    }
}
