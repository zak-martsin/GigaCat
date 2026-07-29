import SwiftUI

struct SessionConflictDialog: View {
    let alert: ProgramSelectionConflictAlert
    let onFinishSession: () -> Void
    let onCancelSession: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppColor.textPrimary.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(alert.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Current session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)

                    Text("\(alert.currentProgramTitle) • \(alert.currentWorkoutDayTitle)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }

                Text(alert.message)
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    Button(action: onCancelSession) {
                        Text("Cancel Session")
                            .frame(maxWidth: .infinity)
                            .frame(height: AppControlSize.buttonHeight)
                    }
                    .buttonStyle(.glass)

                    Button(action: onFinishSession) {
                        Text("Finish Session")
                            .frame(maxWidth: .infinity)
                            .frame(height: AppControlSize.buttonHeight)
                    }
                    .buttonStyle(.glassProminent)
                }

                Button(action: onDismiss) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .frame(height: AppControlSize.buttonHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.textSecondary)
            }
            .padding(AppSpacing.xl)
            .appCardStyle(.elevated)
            .padding(.horizontal, AppSpacing.xl)
        }
        .transition(.opacity)
    }
}
