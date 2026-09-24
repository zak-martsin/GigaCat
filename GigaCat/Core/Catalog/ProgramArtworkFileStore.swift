import Foundation

/// Provides device-local access to versioned workout program artwork files.
protocol ProgramArtworkFileStore: Sendable {
    /// Returns the file only when the requested revision is already stored locally.
    func cachedFileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) async -> URL?

    /// Persists one revision and returns its deterministic local URL.
    @discardableResult
    func save(
        _ data: Data,
        programID: UUID,
        artwork: ProgramArtwork
    ) async throws -> URL
}

enum ProgramArtworkFileStoreError: Error, Equatable {
    case emptyData
}
