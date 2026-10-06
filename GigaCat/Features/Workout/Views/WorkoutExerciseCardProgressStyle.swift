import SwiftUI

struct WorkoutExerciseCardProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let progress = CGFloat(
            min(
                max(configuration.fractionCompleted ?? 0, 0),
                1
            )
        )

        Rectangle()
            .fill(AppColor.progressFill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(x: progress, y: 1, anchor: .leading)
            .animation(.snappy, value: progress)
    }
}
