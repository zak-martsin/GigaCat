import Foundation

/// Provides device-local access to versioned catalog artwork files.
protocol ArtworkFileStore: Sendable {
    /// Returns the file only when the requested revision is already stored locally.
    func cachedFileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async -> URL?

    /// Persists one revision and returns its deterministic local URL.
    @discardableResult
    func save(
        _ data: Data,
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL
}

enum ArtworkFileStoreError: Error, Equatable {
    case emptyData
}
