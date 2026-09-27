import Foundation
import Testing
@testable import GigaCat

struct LocalProgramArtworkFileStoreTests {
    @Test
    func savesAndFindsRequestedArtworkRevision() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let rootDirectoryURL = directoryURL.appending(
            path: "ProgramArtwork",
            directoryHint: .isDirectory
        )
        let store = try LocalProgramArtworkFileStore(
            rootDirectoryURL: rootDirectoryURL
        )
        let programID = UUID()
        let artwork = try ProgramArtwork(path: "remote/hero.jpg", revision: 1)
        let data = Data("image-data".utf8)

        let storedURL = try await store.save(
            data,
            programID: programID,
            artwork: artwork
        )
        let cachedURL = await store.cachedFileURL(
            programID: programID,
            artwork: artwork
        )
        let resourceValues = try rootDirectoryURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )

        #expect(cachedURL == storedURL)
        #expect(try Data(contentsOf: storedURL) == data)
        #expect(resourceValues.isExcludedFromBackup == true)
    }

    @Test
    func successfulNewRevisionRemovesPreviousRevision() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = try LocalProgramArtworkFileStore(
            rootDirectoryURL: directoryURL.appending(
                path: "ProgramArtwork",
                directoryHint: .isDirectory
            )
        )
        let programID = UUID()
        let firstArtwork = try ProgramArtwork(path: "remote/hero.jpg", revision: 1)
        let secondArtwork = try ProgramArtwork(path: "remote/hero.jpg", revision: 2)

        let firstURL = try await store.save(
            Data("first".utf8),
            programID: programID,
            artwork: firstArtwork
        )
        let secondURL = try await store.save(
            Data("second".utf8),
            programID: programID,
            artwork: secondArtwork
        )

        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
        #expect(
            await store.cachedFileURL(
                programID: programID,
                artwork: firstArtwork
            ) == nil
        )
        #expect(
            await store.cachedFileURL(
                programID: programID,
                artwork: secondArtwork
            ) == secondURL
        )
    }

    @Test
    func rejectsEmptyArtworkData() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = try LocalProgramArtworkFileStore(
            rootDirectoryURL: directoryURL.appending(
                path: "ProgramArtwork",
                directoryHint: .isDirectory
            )
        )
        let artwork = try ProgramArtwork(path: "remote/hero.jpg", revision: 1)

        await #expect(throws: ProgramArtworkFileStoreError.emptyData) {
            try await store.save(
                Data(),
                programID: UUID(),
                artwork: artwork
            )
        }
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    return directoryURL
}
