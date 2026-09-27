import Foundation
import Testing
@testable import GigaCat

struct SupabaseProgramArtworkDownloaderTests {
    @Test
    func downloadsArtworkPathUsingRevisionAsCacheNonce() async throws {
        let expectedData = Data("image-data".utf8)
        let storageClient = ProgramArtworkStorageClientSpy(response: expectedData)
        let downloader = SupabaseProgramArtworkDownloader(storageClient: storageClient)
        let artwork = try ProgramArtwork(
            path: "programs/strength/hero.jpg",
            revision: 3
        )

        let data = try await downloader.download(artwork)

        #expect(data == expectedData)
        #expect(
            await storageClient.lastRequest() == .init(
                path: "programs/strength/hero.jpg",
                cacheNonce: "3"
            )
        )
    }
}

private actor ProgramArtworkStorageClientSpy: SupabaseProgramArtworkStorageClient {
    struct Request: Equatable, Sendable {
        let path: String
        let cacheNonce: String
    }

    private let response: Data
    private var requests: [Request] = []

    init(response: Data) {
        self.response = response
    }

    func download(
        path: String,
        cacheNonce: String
    ) -> Data {
        requests.append(Request(path: path, cacheNonce: cacheNonce))
        return response
    }

    func lastRequest() -> Request? {
        requests.last
    }
}
