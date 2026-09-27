import Foundation

protocol ProgramArtworkServicing: Sendable {
    /// Returns the cached file or downloads and stores the requested revision first.
    func fileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) async throws -> URL
}

/// Coordinates remote artwork downloads with the device-local file cache.
actor ProgramArtworkService: ProgramArtworkServicing {
    private let downloader: any ProgramArtworkDownloading
    private let fileStore: any ProgramArtworkFileStore
    private var inFlightTasks: [ArtworkRequestKey: Task<URL, Error>] = [:]

    init(
        downloader: any ProgramArtworkDownloading,
        fileStore: any ProgramArtworkFileStore
    ) {
        self.downloader = downloader
        self.fileStore = fileStore
    }

    func fileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) async throws -> URL {
        if let cachedURL = await fileStore.cachedFileURL(
            programID: programID,
            artwork: artwork
        ) {
            return cachedURL
        }

        let key = ArtworkRequestKey(
            programID: programID,
            path: artwork.path,
            revision: artwork.revision
        )

        if let existingTask = inFlightTasks[key] {
            return try await existingTask.value
        }

        let task = Task { [downloader, fileStore] in
            let data = try await downloader.download(artwork)
            return try await fileStore.save(
                data,
                programID: programID,
                artwork: artwork
            )
        }
        inFlightTasks[key] = task
        defer { inFlightTasks[key] = nil }

        return try await task.value
    }
}

private struct ArtworkRequestKey: Hashable, Sendable {
    let programID: UUID
    let path: String
    let revision: Int
}
