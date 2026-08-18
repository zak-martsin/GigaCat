import Foundation
import Supabase

/// Narrow SDK boundary used to test profile loading without making network requests.
protocol SupabaseProfileClient: Sendable {
    func profile(id: UUID) async throws -> UserProfileDTO
    func updateProfile(
        id: UUID,
        request: UpdateUserProfileDTO
    ) async throws -> UserProfileDTO
}

struct LiveSupabaseProfileClient: SupabaseProfileClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func profile(id: UUID) async throws -> UserProfileDTO {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func updateProfile(
        id: UUID,
        request: UpdateUserProfileDTO
    ) async throws -> UserProfileDTO {
        try await client
            .from("profiles")
            .update(request, returning: .representation)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}
