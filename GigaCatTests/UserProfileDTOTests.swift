import Foundation
import Testing
@testable import GigaCat

struct UserProfileDTOTests {

    @Test
    func codingUsesSupabaseColumnNames() throws {
        let id = try #require(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
        let profile = UserProfileDTO(
            id: id,
            selectedProgramID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let data = try JSONEncoder().encode(profile)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["selected_program_id"] != nil)
        #expect(object["created_at"] != nil)
        #expect(object["updated_at"] != nil)
        #expect(object["selectedProgramID"] == nil)
    }

    @Test
    func updatePayloadEncodesNilAsDatabaseNull() throws {
        let data = try JSONEncoder().encode(
            UpdateUserProfileDTO(selectedProgramID: nil)
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["selected_program_id"] is NSNull)
    }
}

extension UserProfileDTOTests {
    @Test
    func legacyProfileAndOutboxDecodeWithoutPersonalization() throws {
        let id = UUID()
        let profileJSON = """
        {"id":"\(id)","created_at":0,"updated_at":0}
        """
        let profile = try JSONDecoder().decode(UserProfileDTO.self, from: Data(profileJSON.utf8))
        #expect(profile.goal == nil)
        #expect(profile.level == nil)
        #expect(profile.avatarPath == nil)

        let payload = try JSONDecoder().decode(
            UserProfileSyncPayload.self,
            from: Data("{\"selectedProgramID\":null}".utf8)
        )
        #expect(payload.personalization == nil)
        let encoded = try JSONEncoder().encode(UpdateUserProfileDTO(
            selectedProgramID: payload.selectedProgramID,
            personalization: payload.personalization
        ))
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["goal"] == nil)
        #expect(object["level"] == nil)
        #expect(object["avatar_path"] == nil)
    }

    @Test
    func explicitResetEncodesAllPersonalizationColumnsAsNull() throws {
        let request = UpdateUserProfileDTO(
            selectedProgramID: nil,
            personalization: ProfilePersonalization(goal: nil, level: nil, avatarPath: nil)
        )
        let encoded = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["goal"] is NSNull)
        #expect(object["level"] is NSNull)
        #expect(object["avatar_path"] is NSNull)
    }

    @Test
    func populatedFieldsRoundTripThroughOutboxAndRemoteDTO() throws {
        let personalization = ProfilePersonalization(
            goal: .buildMuscle, level: .intermediate, avatarPath: "account/avatar.png"
        )
        let payload = UserProfileSyncPayload(selectedProgramID: UUID(), personalization: personalization)
        let decoded = try JSONDecoder().decode(
            UserProfileSyncPayload.self, from: JSONEncoder().encode(payload)
        )
        #expect(decoded == payload)
        let data = try JSONEncoder().encode(UpdateUserProfileDTO(
            selectedProgramID: decoded.selectedProgramID, personalization: decoded.personalization
        ))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["goal"] as? String == "buildMuscle")
        #expect(object["level"] as? String == "intermediate")
        #expect(object["avatar_path"] as? String == personalization.avatarPath)
    }
}
