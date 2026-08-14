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
}
