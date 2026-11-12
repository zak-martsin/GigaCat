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

extension SupabaseUserProfileRepositoryTests {
    @Test
    func forwardsPersonalizationAndMapsAllReturnedFields() async throws {
        let dto = UserProfileDTO(
            id: UUID(), selectedProgramID: nil, createdAt: Date(), updatedAt: Date(),
            goal: .buildMuscle, level: .advanced, avatarPath: "account/avatar.png"
        )
        let personalization = ProfilePersonalization(
            goal: dto.goal, level: dto.level, avatarPath: dto.avatarPath
        )
        let client = SupabaseProfileClientStub(profile: dto)
        let repository = SupabaseUserProfileRepository(profileClient: client)
        let user = try await repository.updateProfile(
            for: dto.id, selectedProgramID: nil, personalization: personalization
        )
        #expect(user.goal == dto.goal)
        #expect(user.level == dto.level)
        #expect(user.avatarPath == dto.avatarPath)
        #expect(await client.receivedUpdate()?.personalization == personalization)
    }
}

extension SupabaseUserProfileRepositoryTests {
    @Test(arguments: [false, true])
    func executorKeepsLegacyWritesSeparateFromExplicitResets(isReset: Bool) async throws {
        let dto = UserProfileDTO(
            id: UUID(), selectedProgramID: nil, createdAt: Date(), updatedAt: Date(),
            goal: isReset ? nil : .buildMuscle,
            level: isReset ? nil : .advanced,
            avatarPath: isReset ? nil : "account/avatar.png"
        )
        let client = SupabaseProfileClientStub(profile: dto)
        let executor = SupabaseSyncExecutor(
            profileRepository: SupabaseUserProfileRepository(profileClient: client)
        )
        let personalization = isReset
            ? ProfilePersonalization(goal: nil, level: nil, avatarPath: nil) : nil
        let payload = isReset
            ? try JSONEncoder().encode(UserProfileSyncPayload(
                selectedProgramID: nil, personalization: personalization
            ))
            : Data("{\"selectedProgramID\":null}".utf8)
        let operation = SyncOperation(
            id: UUID(), userID: dto.id, aggregateType: .userProfile, aggregateID: dto.id,
            mutation: .update, payload: payload, revision: 1, status: .pending,
            createdAt: Date(), attemptCount: 0, nextAttemptAt: nil
        )
        let result = try await executor.execute(operation)
        let request = try #require(await client.receivedUpdate())
        #expect(request.personalization == personalization)
        #expect(result == .userProfile(UserProfileMapper.toDomain(dto)))
    }
}
