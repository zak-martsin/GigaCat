import SwiftUI

struct CatalogProgramRow: View {
    let item: CatalogProgramItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ProgramArtworkView(
                    fileURL: item.artworkFileURL,
                    height: AppControlSize.catalogProgramArtwork,
                    width: AppControlSize.catalogProgramArtwork
                )

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(2)

                        if item.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColor.textPrimary)
                                .accessibilityLabel("Selected program")
                        }
                    }

                    Text("\(item.dayCount) days • \(item.exerciseCount) exercises")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(AppSpacing.md)
            .appCardStyle(item.isSelected ? .selected : .standard)
        }
        .buttonStyle(.plain)
    }
}
