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
            audience: .men,
            title: "Shared Stack Program",
            description: "Program stored in the factory stack"
        )

        stack.mainContext.insert(UserMapper.toEntity(user))
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(program))
        try stack.mainContext.save()

        let fetchedUser = try await factory.userRepository.user(id: user.id)
        let catalog = try await factory.defaultProgramCatalogRepository.fetchProgramCatalog()

        #expect(fetchedUser == user)
        #expect(catalog.map(\.program) == [program])
    }

    @Test
    func localAndMockDefaultCatalogsApplyTheSameVisibilityContract() async throws {
        let visibleProgram = try WorkoutProgram(title: "Visible", description: "System program")
        let inactiveProgram = try WorkoutProgram(
            isActive: false,
            title: "Inactive",
            description: "Hidden system program"
        )
        let authoredProgram = try WorkoutProgram(
            authorId: UUID(),
            title: "Authored",
            description: "Private user program"
        )
        let programs = [visibleProgram, inactiveProgram, authoredProgram]
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let localRepository = LocalDefaultProgramCatalogRepository(context: stack.mainContext)
        let mockRepository = MockDefaultProgramCatalogRepository(
            store: MockDataStore(programs: programs)
        )

        programs.forEach { stack.mainContext.insert(WorkoutProgramMapper.toEntity($0)) }
        try stack.mainContext.save()

        let localCatalog = try await localRepository.fetchProgramCatalog()
        let mockCatalog = try await mockRepository.fetchProgramCatalog()

        #expect(localCatalog.map(\.id) == [visibleProgram.id])
        #expect(mockCatalog == localCatalog)
    }

    @Test
    func historyLookupIncludesInactivePlannedExercises() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext()
        )
        let program = try WorkoutProgram(
            title: "Archived structure",
            description: "Program with a historical assignment"
        )
        let day = try WorkoutDay(
            programId: program.id,
            title: "Day",
            orderIndex: 0
        )
        let exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
        let assignment = try WorkoutDayExercise(
            workoutDayId: day.id,
            exerciseId: exercise.id,
            orderIndex: 0
        )
        let assignmentEntity = WorkoutDayExerciseMapper.toEntity(assignment)
        let dayEntity = WorkoutDayMapper.toEntity(day)
        dayEntity.isActive = false
        assignmentEntity.isActive = false

        stack.mainContext.insert(WorkoutProgramMapper.toEntity(program))
        stack.mainContext.insert(dayEntity)
        stack.mainContext.insert(ExerciseMapper.toEntity(exercise))
        stack.mainContext.insert(assignmentEntity)
        try stack.mainContext.save()

        let activeDays = try await factory.workoutProgramRepository.fetchWorkoutDays(
            programId: program.id
        )
        let historicalDays = try await factory.workoutProgramRepository
            .fetchWorkoutDaysForHistory(programId: program.id)
        let activeAssignments = try await factory.workoutProgramRepository
            .fetchWorkoutDayExercises(workoutDayId: day.id)
        let historicalAssignments = try await factory.workoutProgramRepository
            .fetchWorkoutDayExercisesForHistory(workoutDayId: day.id)

        #expect(activeDays.isEmpty)
        #expect(historicalDays == [day])
        #expect(activeAssignments.isEmpty)
        #expect(historicalAssignments == [assignment])
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
    func changingCurrentUserIDKeepsProfilesSeparatedAndDefaultCatalogShared() async throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let firstUserID = UUID()
        let secondUserID = UUID()
        let defaultProgram = try WorkoutProgram(
            title: "Shared default program",
            description: "Visible to every local account"
        )
        let currentUserContext = CurrentUserContext(userID: firstUserID)
        let factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: currentUserContext
        )
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(defaultProgram))
        try stack.mainContext.save()

        let firstUser = try await factory.userRepository.currentUser()
        let firstCatalog = try await factory.defaultProgramCatalogRepository
            .fetchProgramCatalog()
        await currentUserContext.setCurrentUserID(secondUserID)
        let secondUser = try await factory.userRepository.currentUser()
        let secondCatalog = try await factory.defaultProgramCatalogRepository
            .fetchProgramCatalog()

        #expect(firstUser?.id == firstUserID)
        #expect(secondUser?.id == secondUserID)
        #expect(firstCatalog.map(\.program) == [defaultProgram])
        #expect(secondCatalog == firstCatalog)
        #expect(
            try stack.mainContext.fetchCount(FetchDescriptor<UserEntity>()) == 2
        )
    }

    @Test
    func selectedProgramChangeSurvivesContainerRecreation() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storeURL = directoryURL.appending(path: "GigaCat.store")
        let identifiers = try await persistSelectedProgram(at: storeURL)

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
        #expect(reopenedUser.id == identifiers.userID)
        #expect(reopenedUser.selectedProgramId == identifiers.programID)
        #expect(
            try reopenedFactory.syncOutboxRepository.operationCount(
                for: identifiers.userID
            ) == 1
        )
    }
}

@MainActor
private func persistSelectedProgram(
    at storeURL: URL
) async throws -> (userID: UUID, programID: UUID) {
    let stack = try SwiftDataStack(storeURL: storeURL)
    let catalog = try BundledDefaultCatalog.load()
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

    _ = try await factory.userRepository.updateSelectedProgram(
        for: user.id,
        programId: program.id
    )

    return (user.id, program.id)
}
