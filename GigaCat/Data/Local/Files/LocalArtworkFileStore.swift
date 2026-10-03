import Foundation

/// Stores remotely managed catalog artwork outside SwiftData for offline access.
actor LocalArtworkFileStore: ArtworkFileStore {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) throws {
        self.fileManager = fileManager

        if let baseDirectoryURL {
            self.baseDirectoryURL = baseDirectoryURL
        } else {
            self.baseDirectoryURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        for ownerKind in ArtworkOwnerKind.allCases {
            try Self.prepareDirectory(
                at: self.baseDirectoryURL.appending(
                    path: ownerKind.directoryName,
                    directoryHint: .isDirectory
                ),
                fileManager: fileManager
            )
        }
    }

    func cachedFileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) -> URL? {
        let fileURL = fileURL(for: owner, artwork: artwork)
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
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) throws -> URL {
        guard !data.isEmpty else {
            throw ArtworkFileStoreError.emptyData
        }

        let ownerDirectoryURL = ownerDirectoryURL(for: owner)
        try fileManager.createDirectory(
            at: ownerDirectoryURL,
            withIntermediateDirectories: true
        )

        let destinationURL = fileURL(for: owner, artwork: artwork)
        if cachedFileExists(at: destinationURL) {
            return destinationURL
        }

        let temporaryURL = ownerDirectoryURL
            .appending(path: ".pending-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try data.write(to: temporaryURL, options: .atomic)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        removeObsoleteRevisions(
            from: ownerDirectoryURL,
            keeping: destinationURL
        )

        return destinationURL
    }
}

private extension LocalArtworkFileStore {
    enum ArtworkOwnerKind: CaseIterable {
        case program
        case exercise

        var directoryName: String {
            switch self {
            case .program:
                "ProgramArtwork"
            case .exercise:
                "ExerciseArtwork"
            }
        }
    }

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

    func rootDirectoryURL(for owner: ArtworkOwner) -> URL {
        let kind: ArtworkOwnerKind
        switch owner {
        case .program:
            kind = .program
        case .exercise:
            kind = .exercise
        }

        return baseDirectoryURL.appending(
            path: kind.directoryName,
            directoryHint: .isDirectory
        )
    }

    func ownerDirectoryURL(for owner: ArtworkOwner) -> URL {
        rootDirectoryURL(for: owner).appending(
            path: owner.id.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
    }

    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) -> URL {
        ownerDirectoryURL(for: owner)
            .appending(path: "revision-\(artwork.revision)")
            .appendingPathExtension(fileExtension(for: artwork))
    }

    func fileExtension(for artwork: ArtworkReference) -> String {
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
