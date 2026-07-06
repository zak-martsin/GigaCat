import SwiftUI

struct PopularProgramRow: View {
    let item: ProgramSectionItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                rowImagePlaceholder

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: AppSpacing.sm) {
                        Text("\(item.dayCount) days")
                        Text("•")
                        Text(trainingLevel)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(AppColor.background)
                        .frame(width: 56, height: 56)

                    Image(systemName: actionSymbolName)
                        .font(.system(size: AppIconSize.headerAction, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(item.isSelected ? AppColor.textPrimary : AppColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var rowImagePlaceholder: some View {
        ProgramArtworkPlaceholderView(height: 108, width: 108) {
            VStack {
                Spacer()

                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColor.surface.opacity(0.14))
                    .frame(width: 42, height: 32)
                    .padding(AppSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private var trainingLevel: String {
        if item.tags.contains(.home) || item.tags.contains(.bodyweight) {
            return "Beginner"
        }

        return item.dayCount >= 5 ? "Intermediate" : "Beginner"
    }

    private var actionSymbolName: String {
        if item.isSelected {
            return "play.fill"
        }

        if let rateScore = item.rateScore, rateScore >= 4.8 {
            return "figure.strengthtraining.traditional"
        }

        return "chart.line.uptrend.xyaxis"
    }
}
