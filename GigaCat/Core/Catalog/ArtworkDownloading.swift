import Foundation

/// Downloads remote bytes for versioned catalog artwork.
protocol ArtworkDownloading: Sendable {
    func download(
        _ artwork: ArtworkReference,
        for owner: ArtworkOwner
    ) async throws -> Data
}
