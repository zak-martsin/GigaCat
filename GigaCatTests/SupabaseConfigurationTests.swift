import Foundation
import Testing
@testable import GigaCat

struct SupabaseConfigurationTests {

    @Test
    func loadsValidConfigurationFile() throws {
        let fileURL = try makeConfigurationFile(
            projectURL: "https://example.supabase.co",
            publishableKey: "publishable-key"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let configuration = try SupabaseConfiguration.load(contentsOf: fileURL)

        #expect(configuration.projectURL.absoluteString == "https://example.supabase.co")
        #expect(configuration.publishableKey == "publishable-key")
    }

    @Test
    func rejectsMissingPublishableKey() throws {
        let fileURL = try makeConfigurationFile(
            projectURL: "https://example.supabase.co",
            publishableKey: ""
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: SupabaseConfigurationError.missingValue("SUPABASE_PUBLISHABLE_KEY")) {
            try SupabaseConfiguration.load(contentsOf: fileURL)
        }
    }

    @Test
    func rejectsInvalidProjectURL() throws {
        let fileURL = try makeConfigurationFile(
            projectURL: "not a project URL",
            publishableKey: "publishable-key"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: SupabaseConfigurationError.invalidProjectURL("not%20a%20project%20URL")) {
            try SupabaseConfiguration.load(contentsOf: fileURL)
        }
    }
}

private func makeConfigurationFile(
    projectURL: String,
    publishableKey: String
) throws -> URL {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appendingPathExtension("plist")
    let values = [
        "SUPABASE_URL": projectURL,
        "SUPABASE_PUBLISHABLE_KEY": publishableKey
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: values,
        format: .xml,
        options: 0
    )
    try data.write(to: fileURL, options: .atomic)
    return fileURL
}
