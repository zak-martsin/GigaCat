import SwiftUI

struct NutritionView: View {
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        PlaceholderFeatureView(
            headerTitle: "Nutrition",
            eyebrow: "Nutrition",
            title: "AI nutrition assistance can plug into this tab later.",
            message: "For now, the shell keeps the information architecture visible while the core workout flows come first.",
            symbolName: AppTab.nutrition.systemImage,
            onHeaderAction: onHeaderAction
        )
    }
}
