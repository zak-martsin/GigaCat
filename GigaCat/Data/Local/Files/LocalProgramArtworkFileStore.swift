import Foundation

/// Stores remotely managed program artwork outside SwiftData for offline access.
actor LocalProgramArtworkFileStore: ProgramArtworkFileStore {
    private let fileManager: FileManager
    private let rootDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        rootDirectoryURL: URL? = nil
    ) throws {
        self.fileManager = fileManager

        let resolvedRootDirectoryURL: URL
        if let rootDirectoryURL {
            resolvedRootDirectoryURL = rootDirectoryURL
        } else {
            resolvedRootDirectoryURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appending(path: "ProgramArtwork", directoryHint: .isDirectory)
        }

        try Self.prepareDirectory(
            at: resolvedRootDirectoryURL,
            fileManager: fileManager
        )
        self.rootDirectoryURL = resolvedRootDirectoryURL
    }

    func cachedFileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) -> URL? {
        let fileURL = fileURL(programID: programID, artwork: artwork)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: fileURL.path,
            isDirectory: &isDirectory
        ),
              !isDirectory.boolValue,
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              (values.fileSize ?? 0) > 0 else {
            return nil
        }

        return fileURL
    }

    func save(
        _ data: Data,
        programID: UUID,
        artwork: ProgramArtwork
    ) throws -> URL {
        guard !data.isEmpty else {
            throw ProgramArtworkFileStoreError.emptyData
        }

        let programDirectoryURL = programDirectoryURL(for: programID)
        try fileManager.createDirectory(
            at: programDirectoryURL,
            withIntermediateDirectories: true
        )

        let destinationURL = fileURL(programID: programID, artwork: artwork)
        if cachedFileExists(at: destinationURL) {
            return destinationURL
        }

        let temporaryURL = programDirectoryURL
            .appending(path: ".pending-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try data.write(to: temporaryURL, options: .atomic)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        removeObsoleteRevisions(
            from: programDirectoryURL,
            keeping: destinationURL
        )

        return destinationURL
    }
}

private extension LocalProgramArtworkFileStore {
    static func prepareDirectory(
        at directoryURL: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        var mutableDirectoryURL = directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableDirectoryURL.setResourceValues(resourceValues)
    }

    func programDirectoryURL(for programID: UUID) -> URL {
        rootDirectoryURL.appending(
            path: programID.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
    }

    func fileURL(
        programID: UUID,
        artwork: ProgramArtwork
    ) -> URL {
        programDirectoryURL(for: programID)
            .appending(path: "revision-\(artwork.revision)")
            .appendingPathExtension(fileExtension(for: artwork))
    }

    func fileExtension(for artwork: ProgramArtwork) -> String {
        let pathExtension = URL(fileURLWithPath: artwork.path)
            .pathExtension
            .lowercased()

        switch pathExtension {
        case "jpg", "jpeg", "png", "heic", "webp":
            return pathExtension
        default:
            return "img"
        }
    }

    func cachedFileExists(at fileURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: fileURL.path),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) else {
            return false
        }
        return (values.fileSize ?? 0) > 0
    }

    func removeObsoleteRevisions(
        from directoryURL: URL,
        keeping destinationURL: URL
    ) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let destinationFileName = destinationURL.lastPathComponent

        fileURLs
            .filter {
                $0.lastPathComponent.hasPrefix("revision-")
                && $0.lastPathComponent != destinationFileName
            }
            .forEach { try? fileManager.removeItem(at: $0) }
    }
}
