import Foundation
import Supabase

/// Reads and updates the signed-in user's row in `public.profiles`.
struct SupabaseUserProfileRepository: UserProfileRemoteRepository {
    private let profileClient: any SupabaseProfileClient

    init(client: SupabaseClient) {
        profileClient = LiveSupabaseProfileClient(client: client)
    }

    init(profileClient: any SupabaseProfileClient) {
        self.profileClient = profileClient
    }

    func profile(for userID: UUID) async throws -> User {
        let dto = try await profileClient.profile(id: userID)
        return UserProfileMapper.toDomain(dto)
    }

    func updateProfile(
        for userID: UUID,
        selectedProgramID: UUID?
    ) async throws -> User {
        let dto = try await profileClient.updateProfile(
            id: userID,
            request: UpdateUserProfileDTO(
                selectedProgramID: selectedProgramID
            )
        )
        return UserProfileMapper.toDomain(dto)
    }
}
