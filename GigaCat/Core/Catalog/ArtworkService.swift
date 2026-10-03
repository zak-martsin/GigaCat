import Foundation

protocol ArtworkServicing: Sendable {
    /// Returns the cached file or downloads and stores the requested revision first.
    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL
}

/// Coordinates remote artwork downloads with the device-local file cache.
actor ArtworkService: ArtworkServicing {
    private let downloader: any ArtworkDownloading
    private let fileStore: any ArtworkFileStore
    private var inFlightTasks: [ArtworkRequestKey: Task<URL, Error>] = [:]

    init(
        downloader: any ArtworkDownloading,
        fileStore: any ArtworkFileStore
    ) {
        self.downloader = downloader
        self.fileStore = fileStore
    }

    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL {
        try Task.checkCancellation()

        if let cachedURL = await fileStore.cachedFileURL(
            for: owner,
            artwork: artwork
        ) {
            return cachedURL
        }

        let key = ArtworkRequestKey(
            owner: owner,
            path: artwork.path,
            revision: artwork.revision
        )

        if let existingTask = inFlightTasks[key] {
            return try await existingTask.value
        }

        let task = Task { [downloader, fileStore] in
            let data = try await downloader.download(artwork, for: owner)
            try Task.checkCancellation()
            return try await fileStore.save(
                data,
                for: owner,
                artwork: artwork
            )
        }
        inFlightTasks[key] = task
        defer { inFlightTasks[key] = nil }

        return try await task.value
    }
}

private struct ArtworkRequestKey: Hashable, Sendable {
    let owner: ArtworkOwner
    let path: String
    let revision: Int
}
