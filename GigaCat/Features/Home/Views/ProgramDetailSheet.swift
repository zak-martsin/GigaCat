import SwiftUI

struct ProgramDetailSheet: View {
    let detail: ProgramDetail
    let onSelectProgram: () -> Void
    let onAddToLibrary: () -> Void
    let onCompleteSession: () -> Void
    let onDeleteSession: () -> Void
    let onOpenWorkout: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ProgramArtworkPlaceholderView(height: 240) {
                    VStack {
                        HStack {
                            Spacer()

                            if let rateScore = detail.rateScore {
                                Text(String(format: "%.1f", rateScore))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.surface)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColor.surface.opacity(0.24), in: Capsule())
                                    .padding(AppSpacing.md)
                            }
                        }

                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(detail.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    HStack(spacing: AppSpacing.sm) {
                        Text("\(detail.dayCount) days")
                        Text("•")
                        Text("\(detail.exerciseCount) exercises")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                    Text(detail.description)
                        .font(.body)
                        .foregroundStyle(AppColor.textPrimary)

                    if let progressText = detail.progressText {
                        Text(progressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColor.background, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppColor.border, lineWidth: 1)
                            }
                    }
                }

                if !detail.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(detail.tags, id: \.self) { tag in
                                AppChipView(
                                    title: tag.title,
                                    isSelected: false,
                                    action: nil
                                )
                            }
                        }
                    }
                }

                if !detail.workoutDayTitles.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Workout Days")
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)

                        VStack(spacing: AppSpacing.sm) {
                            ForEach(Array(detail.workoutDayTitles.enumerated()), id: \.offset) { index, title in
                                HStack(spacing: AppSpacing.md) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppColor.textPrimary)
                                        .frame(width: 28, height: 28)
                                        .background(AppColor.background, in: Circle())

                                    Text(title)
                                        .font(.body)
                                        .foregroundStyle(AppColor.textPrimary)

                                    Spacer()
                                }
                                .padding(AppSpacing.md)
                                .appCardStyle(cornerRadius: AppRadius.md)
                            }
                        }
                    }
                }

                Spacer(minLength: AppSpacing.lg)

                HStack(spacing: AppSpacing.md) {
                    Menu {
                        Button("Add to Library", action: onAddToLibrary)

                        if detail.hasActiveSession {
                            Button("Finish Session", role: .destructive, action: onCompleteSession)
                            Button("Delete Session", role: .destructive, action: onDeleteSession)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: AppIconSize.headerAction, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: AppControlSize.buttonHeight, height: AppControlSize.buttonHeight)
                    }
                    .buttonStyle(.glass)

                    if detail.primaryAction == .chooseProgram {
                        Button(action: onSelectProgram) {
                            Text(detail.primaryAction.title)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppControlSize.buttonHeight)
                        }
                        .buttonStyle(.glassProminent)
                    } else {
                        Button(action: onOpenWorkout) {
                            Text(detail.primaryAction.title)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppControlSize.buttonHeight)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}
