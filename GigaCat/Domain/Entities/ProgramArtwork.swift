import Foundation

/// Versioned reference to artwork supplied with a workout program catalog entry.
struct ProgramArtwork: Codable, Equatable, Sendable {
    let path: String
    let revision: Int

    init(path: String, revision: Int) throws {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyValue(field: "artworkPath")
        }
        guard revision > 0 else {
            throw DomainValidationError.nonPositiveValue(field: "artworkRevision")
        }

        self.path = path
        self.revision = revision
    }
}
