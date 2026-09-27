import Foundation

/// Downloads the remote bytes for a versioned workout program artwork reference.
protocol ProgramArtworkDownloading: Sendable {
    func download(_ artwork: ProgramArtwork) async throws -> Data
}
