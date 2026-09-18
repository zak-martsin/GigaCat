import Foundation
import Testing
@testable import GigaCat

struct SupabaseUserProfileRepositoryTests {

    @Test
    func mapsProfileDTOToDomainUser() async throws {
        let dto = UserProfileDTO(
            id: UUID(),
            selectedProgramID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let client = SupabaseProfileClientStub(profile: dto)
        let repository = SupabaseUserProfileRepository(profileClient: client)

        let user = try await repository.profile(for: dto.id)

        #expect(
            user == User(
                id: dto.id,
                selectedProgramId: dto.selectedProgramID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
        )
        #expect(await client.receivedID() == dto.id)
    }

    @Test
    func updatesSelectedProgramAndMapsReturnedProfile() async throws {
        let dto = UserProfileDTO(
            id: UUID(),
            selectedProgramID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let client = SupabaseProfileClientStub(profile: dto)
        let repository = SupabaseUserProfileRepository(profileClient: client)

        let user = try await repository.updateProfile(
            for: dto.id,
            selectedProgramID: dto.selectedProgramID
        )

        #expect(user.selectedProgramId == dto.selectedProgramID)
        #expect(
            await client.receivedUpdate()
                == UpdateUserProfileDTO(selectedProgramID: dto.selectedProgramID)
        )
    }
}

private actor SupabaseProfileClientStub: SupabaseProfileClient {
    private let profileValue: UserProfileDTO
    private var requestedID: UUID?
    private var updateRequest: UpdateUserProfileDTO?

    init(profile: UserProfileDTO) {
        profileValue = profile
    }

    func profile(id: UUID) -> UserProfileDTO {
        requestedID = id
        return profileValue
    }

    func updateProfile(
        id: UUID,
        request: UpdateUserProfileDTO
    ) -> UserProfileDTO {
        requestedID = id
        updateRequest = request
        return profileValue
    }

    func receivedID() -> UUID? {
        requestedID
    }

    func receivedUpdate() -> UpdateUserProfileDTO? {
        updateRequest
    }
}
