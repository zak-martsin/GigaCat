import Foundation
import Supabase

/// Narrow SDK boundary for downloading files from catalog artwork buckets.
protocol SupabaseArtworkStorageClient: Sendable {
    func download(
        bucket: String,
        path: String,
        cacheNonce: String
    ) async throws -> Data
}

struct LiveSupabaseArtworkStorageClient: SupabaseArtworkStorageClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func download(
        bucket: String,
        path: String,
        cacheNonce: String
    ) async throws -> Data {
        try await client.storage
            .from(bucket)
            .download(
                path: path,
                cacheNonce: cacheNonce
            )
    }
}

/// Downloads catalog artwork from Supabase Storage without exposing the SDK to feature code.
struct SupabaseArtworkDownloader: ArtworkDownloading {
    private let storageClient: any SupabaseArtworkStorageClient

    init(client: SupabaseClient) {
        storageClient = LiveSupabaseArtworkStorageClient(client: client)
    }

    init(storageClient: any SupabaseArtworkStorageClient) {
        self.storageClient = storageClient
    }

    func download(
        _ artwork: ArtworkReference,
        for owner: ArtworkOwner
    ) async throws -> Data {
        try await storageClient.download(
            bucket: bucket(for: owner),
            path: artwork.path,
            cacheNonce: String(artwork.revision)
        )
    }

    private func bucket(for owner: ArtworkOwner) -> String {
        switch owner {
        case .program:
            "program-images"
        case .exercise:
            "exercise-images"
        }
    }
}
