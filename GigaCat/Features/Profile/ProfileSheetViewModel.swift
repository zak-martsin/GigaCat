import Combine
import Foundation

/// Owns an independent editing draft; saving commits locally before any best-effort cloud push.
@MainActor
final class ProfileSheetViewModel: ObservableObject {
    let email: String?
    @Published var goal: TrainingGoal?
    @Published var level: TrainingLevel?
    @Published private(set) var isLoaded = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSyncFailureVisible = false

    private let recoveryService: any ProfileSyncRecovering
    private let userRepository: any UserRepository
    private let userID: UUID
    private let onDataChanged: AppDataChangeHandler
    private var savedUser: User?

    init(
        recoveryService: any ProfileSyncRecovering,
        userID: UUID,
        email: String?,
        userRepository: any UserRepository,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.recoveryService = recoveryService
        self.userID = userID
        self.email = email
        self.userRepository = userRepository
        self.onDataChanged = onDataChanged
    }

    var hasChanges: Bool { goal != savedUser?.goal || level != savedUser?.level }
    var canSave: Bool { isLoaded && hasChanges && !isSaving }

    /// Each presentation starts a new draft; cancellation never writes to the repository.
    func load() async {
        isLoaded = false
        errorMessage = nil
        do {
            guard let user = try await userRepository.user(id: userID) else {
                errorMessage = "Your profile is unavailable. Try again."
                return
            }
            savedUser = user
            goal = user.goal
            level = user.level
            isLoaded = true
        } catch {
            errorMessage = "Could not load your profile. Try again."
        }
        refreshSyncStatus()
    }

    func refreshIfUnedited() async {
        guard isLoaded, !hasChanges, !isSaving else { return }
        await load()
    }

    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            savedUser = try await UpdateTrainingProfileUseCase(userRepository: userRepository)
                .execute(userID: userID, goal: goal, level: level)
            await onDataChanged(.trainingPreferences)
            refreshSyncStatus()
            return true
        } catch {
            errorMessage = "Could not save your profile. Your edits are still here. Try again."
            return false
        }
    }

    /// Returns true only when a newly observed terminal failure needs a brief notice.
    @discardableResult
    func refreshSyncStatus() -> Bool {
        guard let status = try? recoveryService.status(for: userID) else { return false }
        let wasFailed = isSyncFailureVisible
        if case .failed = status { isSyncFailureVisible = true } else { isSyncFailureVisible = false }
        return isSyncFailureVisible && !wasFailed
    }
}
