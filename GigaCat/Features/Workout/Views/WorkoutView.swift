import SwiftUI

struct WorkoutView: View {
    let onHeaderAction: (HeaderAction) -> Void

    var body: some View {
        PlaceholderFeatureView(
            headerTitle: "Workout",
            eyebrow: "Workout",
            title: "Session flow gets its own dedicated tab shell.",
            message: "This gives us a stable navigation surface before we add active session logic and exercise logging.",
            symbolName: AppTab.workout.systemImage,
            onHeaderAction: onHeaderAction
        )
    }
}
