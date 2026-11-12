import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileSheetViewModel
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: AppSpacing.lg) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: AppIconSize.profileAvatar))
                            .foregroundStyle(AppColor.textSecondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Email").font(.subheadline).foregroundStyle(AppColor.textSecondary)
                            Text(viewModel.email ?? "Email unavailable")
                                .textSelection(.enabled)
                                .accessibilityIdentifier("profile.email")
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }

                if viewModel.isLoaded {
                    Section {
                        Picker("Goal", selection: $viewModel.goal) {
                            Text("Not set").tag(TrainingGoal?.none)
                            ForEach(TrainingGoal.allCases, id: \.self) { goal in
                                Text(goal.profileTitle).tag(Optional(goal))
                            }
                        }
                        .accessibilityIdentifier("profile.goal")
                        Picker("Level", selection: $viewModel.level) {
                            Text("Not set").tag(TrainingLevel?.none)
                            ForEach(TrainingLevel.allCases, id: \.self) { level in
                                Text(level.profileTitle).tag(Optional(level))
                            }
                        }
                        .accessibilityIdentifier("profile.level")
                    } header: {
                        Text("Training preferences")
                    } footer: {
                        Text("These preferences recommend your starting sets. You can always add more during a workout.")
                    }
                    .disabled(viewModel.isSaving)
                } else if viewModel.errorMessage == nil {
                    Section { SwiftUI.ProgressView("Loading profile…") }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(AppColor.textSecondary)
                            .accessibilityIdentifier("profile.error")
                        if !viewModel.isLoaded {
                            Button("Retry") { Task { await viewModel.load() } }
                        }
                    }
                }
                if viewModel.isSyncFailureVisible {
                    Section {
                        Label(
                            "Your changes are saved on this device, but could not sync yet.",
                            systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                        )
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityIdentifier("profileSyncFailureStatus")
                    }
                }
                Section {
                    Button("Sign Out", role: .destructive, action: onSignOut)
                        .disabled(viewModel.isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                        .accessibilityIdentifier("profile.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if await viewModel.save() { dismiss() } }
                    } label: {
                        if viewModel.isSaving { SwiftUI.ProgressView() } else { Text("Save") }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("profile.save")
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
        .task {
            await viewModel.load()
            while !Task.isCancelled {
                viewModel.refreshSyncStatus()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

private extension TrainingGoal {
    var profileTitle: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .maintain: "Maintain"
        case .buildMuscle: "Build muscle"
        }
    }
}

private extension TrainingLevel {
    var profileTitle: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
}
