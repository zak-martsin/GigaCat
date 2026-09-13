import Foundation

/// Executes generic outbox operations against the appropriate Supabase repository.
struct SupabaseSyncExecutor: RemoteSyncExecuting {
    private let profileRepository: any UserProfileRemoteRepository

    init(profileRepository: any UserProfileRemoteRepository) {
        self.profileRepository = profileRepository
    }

    func execute(_ operation: SyncOperation) async throws -> SyncExecutionResult {
        guard operation.aggregateType == .userProfile,
              operation.mutation == .update else {
            throw SyncError.unsupportedOperation
        }

        guard let payload = try? JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: operation.payload
        ) else {
            throw SyncError.invalidPayload
        }

        do {
            let profile = try await profileRepository.updateProfile(
                for: operation.aggregateID,
                selectedProgramID: payload.selectedProgramID
            )
            return .userProfile(profile)
        } catch {
            throw SupabaseSyncErrorClassifier.classify(error)
        }
    }
}
