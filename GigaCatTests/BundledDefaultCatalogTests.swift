import CryptoKit
import Foundation
import Testing
@testable import GigaCat

struct BundledDefaultCatalogTests {
    @Test
    func bundledCatalogMatchesSupabaseSeedContract() throws {
        let catalog = try BundledDefaultCatalog.load()

        #expect(catalog.programs.map(\.id) == [
            MockSeedData.uuid("20000000-0000-0000-0000-000000000001"),
            MockSeedData.uuid("20000000-0000-0000-0000-000000000002")
        ])
        #expect(catalog.programs.map(\.title) == ["Сплит для мужчин", "Сплит для женщин"])
        #expect(catalog.workoutDays.count == 6)
        #expect(catalog.dayExercises.count == 50)
        #expect(catalog.exercises.count == 61)
        #expect(catalog.dayExercises.allSatisfy { $0.targetSets == 2 })
        #expect(catalog.dayExercises.allSatisfy { $0.targetReps == nil })
    }

    @Test
    func bundledCatalogSnapshotMatchesReviewedRemoteBaseline() throws {
        let resourceURL = try #require(
            Bundle.main.url(forResource: "DefaultCatalog", withExtension: "json")
        )
        let data = try Data(contentsOf: resourceURL)

        _ = try BundledDefaultCatalog.decode(data)
        let decodedSnapshot = try JSONSerialization.jsonObject(with: data)
        let normalizedSnapshot = try JSONSerialization.data(
            withJSONObject: decodedSnapshot,
            options: [.sortedKeys]
        )
        let fingerprint = SHA256.hash(data: normalizedSnapshot)
            .map { String(format: "%02x", $0) }
            .joined()

        #expect(fingerprint == "2c3aad2332c3c69542342d85a277744d9f85f428d3aae2a0664a2b0faedb2e0a")
    }

    @Test
    func structurallyEmptyBundledCatalogIsRejected() throws {
        let data = Data(
            """
            {
              "programs": [],
              "workoutDays": [],
              "dayExercises": [],
              "exercises": []
            }
            """.utf8
        )

        #expect(throws: BundledDefaultCatalogError.invalidStructure) {
            try BundledDefaultCatalog.decode(data)
        }
    }

    @Test
    func mockActivityUsesProvidedClockAndBundledCatalog() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = try MockSeedData.makeStore(now: now)
        let user = try #require(await store.currentUser())
        let activeSession = try #require(await store.activeSession(for: user.id))
        let programIDs = await store.programs().map(\.id)

        #expect(Set(programIDs) == [
            MockSeedData.uuid("20000000-0000-0000-0000-000000000001"),
            MockSeedData.uuid("20000000-0000-0000-0000-000000000002")
        ])
        #expect(activeSession.startedAt == now.addingTimeInterval(-1_800))
    }
}
