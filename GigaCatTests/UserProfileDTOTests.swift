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
}
