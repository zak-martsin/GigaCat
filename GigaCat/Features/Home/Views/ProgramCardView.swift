import SwiftUI

struct ProgramCardView: View {
    let item: ProgramSectionItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                imagePlaceholder

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .center, spacing: AppSpacing.sm) {
                        Text(item.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: AppSpacing.sm)

                        if item.isSelected {
                            statusBadge("Selected")
                        }
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Text("\(item.dayCount) days")
                        Text("•")
                        Text(trainingLevel)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                    HStack(spacing: AppSpacing.lg) {
                        statRow(systemImage: "star.fill", text: ratingText)
                        statRow(systemImage: "flame.fill", text: "\(item.exerciseCount) ex")
                    }
                }
            }
            .frame(width: 258, alignment: .leading)
            .padding(AppSpacing.md)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(item.isSelected ? AppColor.textPrimary : AppColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some ShapeStyle {
        item.isSelected
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [AppColor.surface, AppColor.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            : AnyShapeStyle(AppColor.surface)
    }

    private var imagePlaceholder: some View {
        ZStack(alignment: .topTrailing) {
            ProgramArtworkPlaceholderView(height: 206) {
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColor.surface.opacity(0.14))
                        .frame(width: 110, height: 84)
                        .padding(AppSpacing.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            statusBadge(item.rateScore == nil ? "New" : "Popular")
                .padding(AppSpacing.md)
        }
    }

    private var trainingLevel: String {
        if item.tags.contains(.home) || item.tags.contains(.bodyweight) {
            return "Beginner"
        }

        return item.dayCount >= 5 ? "Intermediate" : "Beginner"
    }

    private var ratingText: String {
        guard let rateScore = item.rateScore else { return "4.8" }
        return String(format: "%.1f", rateScore)
    }

    private func statRow(systemImage: String, text: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.subheadline)
        }
        .foregroundStyle(AppColor.textPrimary)
    }

    private func statusBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.surface)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.surface.opacity(0.26), in: Capsule())
    }
}
