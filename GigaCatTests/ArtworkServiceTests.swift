import Foundation
import Testing
@testable import GigaCat

struct ArtworkServiceTests {
    @Test
    func returnsCachedFileWithoutDownloading() async throws {
        let cachedURL = URL(fileURLWithPath: "/cached/revision-1.png")
        let downloader = ArtworkDownloaderSpy(data: Data("remote".utf8))
        let fileStore = ArtworkFileStoreSpy(
            cachedURL: cachedURL,
            savedURL: URL(fileURLWithPath: "/saved/revision-1.png")
        )
        let service = ArtworkService(downloader: downloader, fileStore: fileStore)
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 1)

        let result = try await service.fileURL(
            for: .exercise(UUID()),
            artwork: artwork
        )

        #expect(result == cachedURL)
        #expect(await downloader.callCount() == 0)
        #expect(await fileStore.saveCallCount() == 0)
    }

    @Test
    func downloadsAndStoresMissingRevision() async throws {
        let data = Data("remote-image".utf8)
        let savedURL = URL(fileURLWithPath: "/saved/revision-2.png")
        let downloader = ArtworkDownloaderSpy(data: data)
        let fileStore = ArtworkFileStoreSpy(cachedURL: nil, savedURL: savedURL)
        let service = ArtworkService(downloader: downloader, fileStore: fileStore)
        let owner = ArtworkOwner.exercise(UUID())
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 2)

        let result = try await service.fileURL(for: owner, artwork: artwork)

        #expect(result == savedURL)
        #expect(await downloader.lastRequest() == .init(owner: owner, artwork: artwork))
        #expect(
            await fileStore.savedRequest() == .init(
                data: data,
                owner: owner,
                artwork: artwork
            )
        )
    }

    @Test
    func doesNotSaveWhenDownloadFails() async throws {
        let downloader = ArtworkDownloaderSpy(error: ArtworkDownloadTestError.failed)
        let fileStore = ArtworkFileStoreSpy(
            cachedURL: nil,
            savedURL: URL(fileURLWithPath: "/saved/revision-1.png")
        )
        let service = ArtworkService(downloader: downloader, fileStore: fileStore)
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 1)

        await #expect(throws: ArtworkDownloadTestError.failed) {
            try await service.fileURL(for: .exercise(UUID()), artwork: artwork)
        }
        #expect(await fileStore.saveCallCount() == 0)
    }

    @Test
    func concurrentRequestsShareOneDownload() async throws {
        let savedURL = URL(fileURLWithPath: "/saved/revision-2.png")
        let downloader = ArtworkDownloaderSpy(
            data: Data("remote-image".utf8),
            delay: .milliseconds(50)
        )
        let fileStore = ArtworkFileStoreSpy(cachedURL: nil, savedURL: savedURL)
        let service = ArtworkService(downloader: downloader, fileStore: fileStore)
        let owner = ArtworkOwner.exercise(UUID())
        let artwork = try ArtworkReference(path: "exercise/main.png", revision: 2)

        async let rowURL = service.fileURL(for: owner, artwork: artwork)
        async let detailURL = service.fileURL(for: owner, artwork: artwork)
        let results = try await (rowURL, detailURL)

        #expect(results.0 == savedURL)
        #expect(results.1 == savedURL)
        #expect(await downloader.callCount() == 1)
        #expect(await fileStore.saveCallCount() == 1)
    }
}

private enum ArtworkDownloadTestError: Error {
    case failed
}

private actor ArtworkDownloaderSpy: ArtworkDownloading {
    struct Request: Equatable, Sendable {
        let owner: ArtworkOwner
        let artwork: ArtworkReference
    }

    private let result: Result<Data, ArtworkDownloadTestError>
    private let delay: Duration?
    private var requests: [Request] = []

    init(data: Data, delay: Duration? = nil) {
        result = .success(data)
        self.delay = delay
    }

    init(error: ArtworkDownloadTestError) {
        result = .failure(error)
        delay = nil
    }

    func download(
        _ artwork: ArtworkReference,
        for owner: ArtworkOwner
    ) async throws -> Data {
        requests.append(Request(owner: owner, artwork: artwork))
        if let delay {
            try await Task.sleep(for: delay)
        }
        return try result.get()
    }

    func callCount() -> Int {
        requests.count
    }

    func lastRequest() -> Request? {
        requests.last
    }
}

private actor ArtworkFileStoreSpy: ArtworkFileStore {
    struct SaveRequest: Equatable, Sendable {
        let data: Data
        let owner: ArtworkOwner
        let artwork: ArtworkReference
    }

    private let cachedURL: URL?
    private let savedURL: URL
    private var saveRequests: [SaveRequest] = []

    init(cachedURL: URL?, savedURL: URL) {
        self.cachedURL = cachedURL
        self.savedURL = savedURL
    }

    func cachedFileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) -> URL? {
        cachedURL
    }

    func save(
        _ data: Data,
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) -> URL {
        saveRequests.append(
            SaveRequest(data: data, owner: owner, artwork: artwork)
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
