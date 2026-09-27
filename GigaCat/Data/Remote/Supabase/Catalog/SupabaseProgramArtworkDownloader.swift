import Foundation
import Supabase

/// Narrow SDK boundary for downloading files from the program artwork bucket.
protocol SupabaseProgramArtworkStorageClient: Sendable {
    func download(
        path: String,
        cacheNonce: String
    ) async throws -> Data
}

struct LiveSupabaseProgramArtworkStorageClient: SupabaseProgramArtworkStorageClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func download(
        path: String,
        cacheNonce: String
    ) async throws -> Data {
        try await client.storage
            .from("program-images")
            .download(
                path: path,
                cacheNonce: cacheNonce
            )
    }
}

/// Downloads program artwork from Supabase Storage without exposing the SDK to feature code.
struct SupabaseProgramArtworkDownloader: ProgramArtworkDownloading {
    private let storageClient: any SupabaseProgramArtworkStorageClient

    init(client: SupabaseClient) {
        storageClient = LiveSupabaseProgramArtworkStorageClient(client: client)
    }

    init(storageClient: any SupabaseProgramArtworkStorageClient) {
        self.storageClient = storageClient
    }

    func download(_ artwork: ProgramArtwork) async throws -> Data {
        try await storageClient.download(
            path: artwork.path,
            cacheNonce: String(artwork.revision)
        )
    }
}
