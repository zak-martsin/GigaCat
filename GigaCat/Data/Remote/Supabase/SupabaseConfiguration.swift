import Foundation

enum SupabaseConfigurationError: Error, Equatable {
    case configurationFileNotFound
    case invalidConfigurationFile
    case missingValue(String)
    case invalidProjectURL(String)
}

/// Values required to connect the application to one Supabase project.
struct SupabaseConfiguration: Equatable, Sendable {
    let projectURL: URL
    let publishableKey: String

    init(projectURL: URL, publishableKey: String) throws {
        guard let scheme = projectURL.scheme,
              ["http", "https"].contains(scheme),
              projectURL.host != nil else {
            throw SupabaseConfigurationError.invalidProjectURL(projectURL.absoluteString)
        }

        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw SupabaseConfigurationError.missingValue("SUPABASE_PUBLISHABLE_KEY")
        }

        self.projectURL = projectURL
        self.publishableKey = trimmedKey
    }

    /// Loads the untracked project values bundled from `SupabaseConfig.plist`.
    static func load(from bundle: Bundle = .main) throws -> SupabaseConfiguration {
        guard let fileURL = bundle.url(
            forResource: "SupabaseConfig",
            withExtension: "plist"
        ) else {
            throw SupabaseConfigurationError.configurationFileNotFound
        }

        return try load(contentsOf: fileURL)
    }

    /// Loads a specific plist URL so configuration parsing can be tested without app globals.
    static func load(contentsOf fileURL: URL) throws -> SupabaseConfiguration {
        let file: SupabaseConfigurationFile
        do {
            let data = try Data(contentsOf: fileURL)
            file = try PropertyListDecoder().decode(
                SupabaseConfigurationFile.self,
                from: data
            )
        } catch {
            throw SupabaseConfigurationError.invalidConfigurationFile
        }

        let rawURL = file.projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty else {
            throw SupabaseConfigurationError.missingValue("SUPABASE_URL")
        }
        guard let projectURL = URL(string: rawURL) else {
            throw SupabaseConfigurationError.invalidProjectURL(rawURL)
        }

        return try SupabaseConfiguration(
            projectURL: projectURL,
            publishableKey: file.publishableKey
        )
    }
}

private struct SupabaseConfigurationFile: Decodable {
    let projectURL: String
    let publishableKey: String

    enum CodingKeys: String, CodingKey {
        case projectURL = "SUPABASE_URL"
        case publishableKey = "SUPABASE_PUBLISHABLE_KEY"
    }
}
