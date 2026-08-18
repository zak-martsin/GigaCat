import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct LocalRepositoryFactoryTests {

    @Test
    func repositoriesReadFromSharedStack() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext()
        )
        let user = User()
        let program = try WorkoutProgram(
            title: "Shared Stack Program",
            description: "Program stored in the factory stack"
        )

        stack.mainContext.insert(UserMapper.toEntity(user))
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(program))
        try stack.mainContext.save()

        let fetchedUser = try await factory.userRepository.user(id: user.id)
        let catalog = try await factory.programCatalogRepository.fetchProgramCatalog()

        #expect(fetchedUser == user)
        #expect(catalog.map(\.program) == [program])
    }

    @Test
    func currentUserIsCreatedOnceThenReadFromSwiftData() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let currentUserID = UUID()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: currentUserID)
        )

        let firstRead = try await factory.userRepository.currentUser()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: currentUserID,
            programId: nil
        )
        let secondRead = try await factory.userRepository.currentUser()

        #expect(firstRead?.id == currentUserID)
        #expect(secondRead?.selectedProgramId == nil)
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<UserEntity>()) == 1
        )
        let operation = try #require(
            try stack.mainContext.fetch(FetchDescriptor<SyncOperationEntity>()).first
        )
        #expect(operation.userId == currentUserID)
        #expect(operation.revision == 1)
        #expect(operation.statusRawValue == SyncOperationStatus.pending.rawValue)
    }

    @Test
    func changingCurrentUserIDKeepsLocalProfilesSeparated() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let firstUserID = UUID()
        let secondUserID = UUID()
        let currentUserContext = CurrentUserContext(userID: firstUserID)
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: currentUserContext
        )

        let firstUser = try await factory.userRepository.currentUser()
        await currentUserContext.setCurrentUserID(secondUserID)
        let secondUser = try await factory.userRepository.currentUser()

        #expect(firstUser?.id == firstUserID)
        #expect(secondUser?.id == secondUserID)
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<UserEntity>()) == 2
        )
    }

    @Test
    func savedProgramAndUserChangesSurviveContainerRecreation() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storeURL = directoryURL.appending(path: "GigaCat.store")
        let identifiers = try await persistUserChangesAndProgram(at: storeURL)

        let reopenedStack = try SwiftDataStack(storeURL: storeURL)
        let reopenedFactory = LocalRepositoryFactory(
            stack: reopenedStack,
            currentUserIDProvider: CurrentUserContext(
                userID: identifiers.userID
            )
        )
        let reopenedUser = try #require(
            try await reopenedFactory.userRepository.currentUser()
        )
        let savedPrograms = try await reopenedFactory.workoutProgramLibraryRepository
            .fetchSavedPrograms(for: reopenedUser.id)

        #expect(reopenedUser.id == identifiers.userID)
        #expect(reopenedUser.selectedProgramId == nil)
        #expect(savedPrograms.map(\.id) == [identifiers.programID])
        #expect(
            try reopenedFactory.syncOutboxRepository.operationCount(
                for: identifiers.userID
            ) == 1
        )
    }
}

@MainActor
private func persistUserChangesAndProgram(
    at storeURL: URL
) async throws -> (userID: UUID, programID: UUID) {
    let stack = try SwiftDataStack(storeURL: storeURL)
    let catalog = MockSeedData.makeCatalogSeed()
    try SwiftDataBootstrapService(
        context: stack.mainContext,
        catalog: catalog
    ).bootstrapIfNeeded()

    let factory = LocalRepositoryFactory(
        stack: stack,
        currentUserIDProvider: CurrentUserContext(
            userID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
    )
    let user = try #require(try await factory.userRepository.currentUser())
    let program = try #require(catalog.programs.first)

    try await factory.workoutProgramLibraryRepository.saveProgram(
        program.id,
        for: user.id
    )
    _ = try await factory.userRepository.updateSelectedProgram(
        for: user.id,
        programId: nil
    )

    return (user.id, program.id)
}
