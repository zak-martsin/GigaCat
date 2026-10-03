import Foundation
import Testing
@testable import GigaCat

struct LocalArtworkFileStoreTests {
    @Test
    func storesProgramsInExistingDirectoryAndExercisesSeparately() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = try LocalArtworkFileStore(baseDirectoryURL: directoryURL)
        let identifier = UUID()
        let artwork = try ArtworkReference(path: "remote/main.png", revision: 1)

        let programURL = try await store.save(
            Data("program".utf8),
            for: .program(identifier),
            artwork: artwork
        )
        let exerciseURL = try await store.save(
            Data("exercise".utf8),
            for: .exercise(identifier),
            artwork: artwork
        )

        #expect(programURL.path.contains("/ProgramArtwork/"))
        #expect(exerciseURL.path.contains("/ExerciseArtwork/"))
        #expect(programURL != exerciseURL)
        #expect(
            await store.cachedFileURL(
                for: .program(identifier),
                artwork: artwork
            ) == programURL
        )
        #expect(
            await store.cachedFileURL(
                for: .exercise(identifier),
                artwork: artwork
            ) == exerciseURL
        )
    }

    @Test
    func successfulNewRevisionRemovesOnlyTheOwnersPreviousRevision() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = try LocalArtworkFileStore(baseDirectoryURL: directoryURL)
        let identifier = UUID()
        let firstArtwork = try ArtworkReference(path: "remote/main.png", revision: 1)
        let secondArtwork = try ArtworkReference(path: "remote/main.png", revision: 2)

        let programURL = try await store.save(
            Data("program".utf8),
            for: .program(identifier),
            artwork: firstArtwork
        )
        let firstExerciseURL = try await store.save(
            Data("first".utf8),
            for: .exercise(identifier),
            artwork: firstArtwork
        )
        let secondExerciseURL = try await store.save(
            Data("second".utf8),
            for: .exercise(identifier),
            artwork: secondArtwork
        )

        #expect(FileManager.default.fileExists(atPath: programURL.path))
        #expect(!FileManager.default.fileExists(atPath: firstExerciseURL.path))
        #expect(FileManager.default.fileExists(atPath: secondExerciseURL.path))
    }

    @Test
    func catalogArtworkDirectoriesAreExcludedFromBackup() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        _ = try LocalArtworkFileStore(baseDirectoryURL: directoryURL)

        for directoryName in ["ProgramArtwork", "ExerciseArtwork"] {
            let values = try directoryURL
                .appending(path: directoryName, directoryHint: .isDirectory)
                .resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup == true)
        }
    }

    @Test
    func rejectsEmptyArtworkData() async throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = try LocalArtworkFileStore(baseDirectoryURL: directoryURL)
        let artwork = try ArtworkReference(path: "remote/main.png", revision: 1)

        await #expect(throws: ArtworkFileStoreError.emptyData) {
            try await store.save(
                Data(),
                for: .exercise(UUID()),
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
