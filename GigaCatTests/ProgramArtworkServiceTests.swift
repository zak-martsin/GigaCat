import Foundation
import Testing
@testable import GigaCat

struct ProgramArtworkServiceTests {
    @Test
    func returnsCachedFileWithoutDownloading() async throws {
        let cachedURL = URL(fileURLWithPath: "/cached/revision-1.jpg")
        let downloader = ProgramArtworkDownloaderSpy(data: Data("remote".utf8))
        let fileStore = ProgramArtworkFileStoreSpy(
            cachedURL: cachedURL,
            savedURL: URL(fileURLWithPath: "/saved/revision-1.jpg")
        )
        let service = ProgramArtworkService(
            downloader: downloader,
            fileStore: fileStore
        )
        let artwork = try ProgramArtwork(path: "program/hero.jpg", revision: 1)

        let result = try await service.fileURL(
            programID: UUID(),
            artwork: artwork
        )

        #expect(result == cachedURL)
        #expect(await downloader.callCount() == 0)
        #expect(await fileStore.saveCallCount() == 0)
    }

    @Test
    func downloadsAndStoresMissingRevision() async throws {
        let data = Data("remote-image".utf8)
        let savedURL = URL(fileURLWithPath: "/saved/revision-2.jpg")
        let downloader = ProgramArtworkDownloaderSpy(data: data)
        let fileStore = ProgramArtworkFileStoreSpy(
            cachedURL: nil,
            savedURL: savedURL
        )
        let service = ProgramArtworkService(
            downloader: downloader,
            fileStore: fileStore
        )
        let programID = UUID()
        let artwork = try ProgramArtwork(path: "program/hero.jpg", revision: 2)

        let result = try await service.fileURL(
            programID: programID,
            artwork: artwork
        )

        #expect(result == savedURL)
        #expect(await downloader.downloadedArtwork() == artwork)
        #expect(
            await fileStore.savedRequest() == .init(
                data: data,
                programID: programID,
                artwork: artwork
            )
        )
    }

    @Test
    func doesNotSaveWhenDownloadFails() async throws {
        let downloader = ProgramArtworkDownloaderSpy(error: ArtworkDownloadTestError.failed)
        let fileStore = ProgramArtworkFileStoreSpy(
            cachedURL: nil,
            savedURL: URL(fileURLWithPath: "/saved/revision-1.jpg")
        )
        let service = ProgramArtworkService(
            downloader: downloader,
            fileStore: fileStore
        )
        let artwork = try ProgramArtwork(path: "program/hero.jpg", revision: 1)

        await #expect(throws: ArtworkDownloadTestError.failed) {
            try await service.fileURL(
                programID: UUID(),
                artwork: artwork
            )
        }
        #expect(await fileStore.saveCallCount() == 0)
    }

    @Test
    func concurrentRequestsShareOneDownload() async throws {
        let savedURL = URL(fileURLWithPath: "/saved/revision-2.jpg")
        let downloader = ProgramArtworkDownloaderSpy(
            data: Data("remote-image".utf8),
            delay: .milliseconds(50)
        )
        let fileStore = ProgramArtworkFileStoreSpy(
            cachedURL: nil,
            savedURL: savedURL
        )
        let service = ProgramArtworkService(
            downloader: downloader,
            fileStore: fileStore
        )
        let programID = UUID()
        let artwork = try ProgramArtwork(path: "program/hero.jpg", revision: 2)

        async let catalogURL = service.fileURL(
            programID: programID,
            artwork: artwork
        )
        async let workoutURL = service.fileURL(
            programID: programID,
            artwork: artwork
        )

        let results = try await (catalogURL, workoutURL)

        #expect(results.0 == savedURL)
        #expect(results.1 == savedURL)
        #expect(await downloader.callCount() == 1)
        #expect(await fileStore.saveCallCount() == 1)
    }
}

private enum ArtworkDownloadTestError: Error {
    case failed
}

private actor ProgramArtworkDownloaderSpy: ProgramArtworkDownloading {
    private let result: Result<Data, ArtworkDownloadTestError>
    private let delay: Duration?
    private var artworks: [ProgramArtwork] = []

    init(data: Data, delay: Duration? = nil) {
        result = .success(data)
        self.delay = delay
    }

    init(error: ArtworkDownloadTestError) {
        result = .failure(error)
        delay = nil
    }

    func download(_ artwork: ProgramArtwork) async throws -> Data {
        artworks.append(artwork)
        if let delay {
            try await Task.sleep(for: delay)
        }
        return try result.get()
    }

    func callCount() -> Int {
        artworks.count
    }

    func downloadedArtwork() -> ProgramArtwork? {
        artworks.last
    }
}

private actor ProgramArtworkFileStoreSpy: ProgramArtworkFileStore {
    struct SaveRequest: Equatable, Sendable {
        let data: Data
        let programID: UUID
        let artwork: ProgramArtwork
    }

    private let cachedURL: URL?
    private let savedURL: URL
    private var saveRequests: [SaveRequest] = []

    init(cachedURL: URL?, savedURL: URL) {
        self.cachedURL = cachedURL
        self.savedURL = savedURL
    }

    func cachedFileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) -> URL? {
        cachedURL
    }

    func save(
        _ data: Data,
        programID: UUID,
        artwork: ProgramArtwork
    ) -> URL {
        saveRequests.append(
            SaveRequest(
                data: data,
                programID: programID,
                artwork: artwork
            )
        )
        return savedURL
    }

    func saveCallCount() -> Int {
        saveRequests.count
    }

    func savedRequest() -> SaveRequest? {
        saveRequests.last
    }
}
