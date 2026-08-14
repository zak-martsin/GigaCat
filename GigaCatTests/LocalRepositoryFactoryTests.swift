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
            currentUserStore: MockDataStore()
        )
        let user = try User(appleUserId: "shared-stack-user")
        let program = try WorkoutProgram(
            title: "Shared Stack Program",
            description: "Program stored in the factory stack"
        )

        stack.mainContext.insert(UserMapper.toEntity(user))
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(program))
        try stack.mainContext.save()

        let fetchedUser = try await factory.userRepository.user(
            appleUserId: user.appleUserId
        )
        let catalog = try await factory.programCatalogRepository.fetchProgramCatalog()

        #expect(fetchedUser == user)
        #expect(catalog.map(\.program) == [program])
    }

    @Test
    func currentUserIsCreatedOnceThenReadFromSwiftData() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let currentUserStore = MockSeedData.makeStore()
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserStore: currentUserStore
        )
        let authenticatedUser = try #require(await currentUserStore.currentUser())
        #expect(authenticatedUser.selectedProgramId != nil)

        let firstRead = try await factory.userRepository.currentUser()
        _ = try await factory.userRepository.updateSelectedProgram(
            for: authenticatedUser.id,
            programId: nil
        )
        let secondRead = try await factory.userRepository.currentUser()

        #expect(firstRead == authenticatedUser)
        #expect(secondRead?.selectedProgramId == nil)
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<UserEntity>()) == 1
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
            currentUserStore: MockSeedData.makeStore()
        )
        let reopenedUser = try #require(
            try await reopenedFactory.userRepository.currentUser()
        )
        let savedPrograms = try await reopenedFactory.workoutProgramLibraryRepository
            .fetchSavedPrograms(for: reopenedUser.id)

        #expect(reopenedUser.id == identifiers.userID)
        #expect(reopenedUser.selectedProgramId == nil)
        #expect(savedPrograms.map(\.id) == [identifiers.programID])
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
        currentUserStore: MockSeedData.makeStore()
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
