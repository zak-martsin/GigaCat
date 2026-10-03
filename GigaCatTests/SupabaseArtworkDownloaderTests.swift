import Foundation
import Testing
@testable import GigaCat

struct SupabaseArtworkDownloaderTests {
    @Test
    func selectsBucketAndUsesRevisionAsCacheNonce() async throws {
        let expectedData = Data("image-data".utf8)
        let storageClient = ArtworkStorageClientSpy(response: expectedData)
        let downloader = SupabaseArtworkDownloader(storageClient: storageClient)
        let artwork = try ArtworkReference(path: "owner/main.png", revision: 3)

        let programData = try await downloader.download(
            artwork,
            for: .program(UUID())
        )
        let exerciseData = try await downloader.download(
            artwork,
            for: .exercise(UUID())
        )

        #expect(programData == expectedData)
        #expect(exerciseData == expectedData)
        #expect(
            await storageClient.requests() == [
                .init(
                    bucket: "program-images",
                    path: "owner/main.png",
                    cacheNonce: "3"
                ),
                .init(
                    bucket: "exercise-images",
                    path: "owner/main.png",
                    cacheNonce: "3"
                )
            ]
        )
    }
}

private actor ArtworkStorageClientSpy: SupabaseArtworkStorageClient {
    struct Request: Equatable, Sendable {
        let bucket: String
        let path: String
        let cacheNonce: String
    }

    private let response: Data
    private var recordedRequests: [Request] = []

    init(response: Data) {
        self.response = response
    }

    func download(
        bucket: String,
        path: String,
        cacheNonce: String
    ) -> Data {
        recordedRequests.append(
            Request(bucket: bucket, path: path, cacheNonce: cacheNonce)
        )
        return response
    }

    func requests() -> [Request] {
        recordedRequests
    }
}
