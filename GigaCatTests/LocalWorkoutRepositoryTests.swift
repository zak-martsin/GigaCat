import Foundation
import SwiftData
import Testing
@testable import GigaCat

@MainActor
struct LocalWorkoutRepositoryTests {

    @Test
    func startSessionPersistsActiveSessionAndRejectsSecondOne() async throws {
        let fixture = try Fixture()
        let startedAt = Date(timeIntervalSince1970: 1_000)

        let session = try await fixture.repository.startSession(
            userId: fixture.user.id,
            workoutDayId: fixture.day.id,
            startedAt: startedAt
        )

        #expect(try await fixture.repository.activeSession(for: fixture.user.id) == session)

        await #expect(throws: RepositoryError.activeSessionAlreadyExists) {
            try await fixture.repository.startSession(
                userId: fixture.user.id,
                workoutDayId: fixture.otherDay.id,
                startedAt: startedAt.addingTimeInterval(100)
            )
        }
    }

    @Test
    func repeatedSetUpdatesExistingLogWithoutCreatingDuplicate() async throws {
        let fixture = try Fixture()
        let firstResult = try await fixture.repository.saveSet(
            fixture.input(weight: 60, reps: 8)
        )
        let updatedResult = try await fixture.repository.saveSet(
            fixture.input(weight: 62.5, reps: 7)
        )

        let logs = try await fixture.repository.fetchExerciseLogs(
            sessionId: firstResult.session.id
        )

        #expect(firstResult.didStartSession)
        #expect(updatedResult.didStartSession == false)
        #expect(updatedResult.log.id == firstResult.log.id)
        #expect(updatedResult.log.weight == 62.5)
        #expect(updatedResult.log.reps == 7)
        #expect(logs == [updatedResult.log])
    }

    @Test
    func invalidFirstSetDoesNotPersistEmptySession() async throws {
        let fixture = try Fixture()

        await #expect(throws: DomainValidationError.nonPositiveValue(field: "reps")) {
            try await fixture.repository.saveSet(fixture.input(reps: 0))
        }

        #expect(try await fixture.repository.activeSession(for: fixture.user.id) == nil)
        #expect(try await fixture.repository.fetchSessions(for: fixture.user.id).isEmpty)
    }

    @Test
    func setForAnotherDayIsRejectedWhileSessionIsActive() async throws {
        let fixture = try Fixture()
        let firstResult = try await fixture.repository.saveSet(fixture.input())

        await #expect(throws: RepositoryError.activeSessionWorkoutDayConflict) {
            try await fixture.repository.saveSet(fixture.otherDayInput())
        }

        #expect(
            try await fixture.repository.activeSession(for: fixture.user.id) == firstResult.session
        )
        #expect(try await fixture.repository.fetchSessions(for: fixture.user.id).count == 1)
    }

    @Test
    func deletingSessionAlsoDeletesItsExerciseLogs() async throws {
        let fixture = try Fixture()
        let result = try await fixture.repository.saveSet(fixture.input())

        try await fixture.repository.deleteSession(sessionId: result.session.id)

        #expect(try await fixture.repository.fetchSessions(for: fixture.user.id).isEmpty)
        #expect(
            try await fixture.repository.fetchExerciseLogs(sessionId: result.session.id).isEmpty
        )
    }

    @Test
    func completeSessionAndSelectProgramPersistsBothChanges() async throws {
        let fixture = try Fixture()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let completedAt = Date(timeIntervalSince1970: 2_000)
        let session = try await fixture.repository.startSession(
            userId: fixture.user.id,
            workoutDayId: fixture.day.id,
            startedAt: startedAt
        )

        let updatedUser = try await fixture.repository.completeSessionAndSelectProgram(
            sessionId: session.id,
            completedAt: completedAt,
            userId: fixture.user.id,
            programId: fixture.program.id
        )
        let sessions = try await fixture.repository.fetchSessions(for: fixture.user.id)

        #expect(updatedUser.selectedProgramId == fixture.program.id)
        #expect(sessions.first?.status == .completed)
        #expect(sessions.first?.completedAt == completedAt)
        #expect(try fixture.persistedUser().selectedProgramId == fixture.program.id)
    }

    @Test
    func completeAndSelectLeavesSessionUnchangedWhenProgramIsMissing() async throws {
        let fixture = try Fixture()
        let session = try await fixture.repository.startSession(
            userId: fixture.user.id,
            workoutDayId: fixture.day.id,
            startedAt: Date(timeIntervalSince1970: 1_000)
        )

        await #expect(throws: RepositoryError.workoutProgramNotFound) {
            try await fixture.repository.completeSessionAndSelectProgram(
                sessionId: session.id,
                completedAt: Date(timeIntervalSince1970: 2_000),
                userId: fixture.user.id,
                programId: UUID()
            )
        }

        let activeSession = try await fixture.repository.activeSession(for: fixture.user.id)
        #expect(activeSession == session)
        #expect(try fixture.persistedUser().selectedProgramId == nil)
    }

    @Test
    func sessionsAndLogsAreReturnedInExpectedOrder() async throws {
        let fixture = try Fixture()
        let first = try await fixture.repository.saveSet(
            fixture.input(setNumber: 2, performedAt: Date(timeIntervalSince1970: 1_200))
        )
        _ = try await fixture.repository.saveSet(
            fixture.input(setNumber: 1, performedAt: Date(timeIntervalSince1970: 1_100))
        )
        _ = try await fixture.repository.completeSession(
            sessionId: first.session.id,
            completedAt: Date(timeIntervalSince1970: 1_300)
        )
        let second = try await fixture.repository.startSession(
            userId: fixture.user.id,
            workoutDayId: fixture.otherDay.id,
            startedAt: Date(timeIntervalSince1970: 2_000)
        )

        let sessions = try await fixture.repository.fetchSessions(for: fixture.user.id)
        let logs = try await fixture.repository.fetchExerciseLogs(sessionId: first.session.id)

        #expect(sessions.map(\.id) == [second.id, first.session.id])
        #expect(logs.map(\.setNumber) == [1, 2])
    }

    @Test
    func latestExerciseLogUsesOnlyRequestedUsersSessions() async throws {
        let fixture = try Fixture()
        let expected = try await fixture.repository.saveSet(
            fixture.input(performedAt: Date(timeIntervalSince1970: 2_000))
        ).log
        let otherUser = User()
        fixture.context.insert(UserMapper.toEntity(otherUser))
        try fixture.context.save()

        _ = try await fixture.repository.saveSet(
            fixture.input(
                userId: otherUser.id,
                performedAt: Date(timeIntervalSince1970: 3_000)
            )
        )

        let latest = try await fixture.repository.fetchLatestExerciseLog(
            userId: fixture.user.id,
            exerciseId: fixture.exercise.id
        )

        #expect(latest == expected)
    }
}

private extension LocalWorkoutRepositoryTests {
    @MainActor
    struct Fixture {
        let stack: SwiftDataStack
        let context: ModelContext
        let repository: LocalWorkoutRepository
        let user: User
        let program: WorkoutProgram
        let day: WorkoutDay
        let otherDay: WorkoutDay
        let exercise: Exercise
        let dayExercise: WorkoutDayExercise
        let otherDayExercise: WorkoutDayExercise

        init() throws {
            stack = try SwiftDataStack(isStoredInMemoryOnly: true)
            context = stack.mainContext
            repository = LocalWorkoutRepository(context: context)

            user = User()
            program = try WorkoutProgram(
                title: "Local Program",
                description: "Program used by local repository tests"
            )
            day = try WorkoutDay(
                programId: program.id,
                title: "Day 1",
                orderIndex: 0
            )
            otherDay = try WorkoutDay(
                programId: program.id,
                title: "Day 2",
                orderIndex: 1
            )
            exercise = try Exercise(name: "Bench Press", muscleGroup: .chest)
            dayExercise = try WorkoutDayExercise(
                workoutDayId: day.id,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )
            otherDayExercise = try WorkoutDayExercise(
                workoutDayId: otherDay.id,
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )

            context.insert(UserMapper.toEntity(user))
            context.insert(WorkoutProgramMapper.toEntity(program))
            context.insert(WorkoutDayMapper.toEntity(day))
            context.insert(WorkoutDayMapper.toEntity(otherDay))
            context.insert(ExerciseMapper.toEntity(exercise))
            context.insert(WorkoutDayExerciseMapper.toEntity(dayExercise))
            context.insert(WorkoutDayExerciseMapper.toEntity(otherDayExercise))
            try context.save()
        }

        func input(
            userId: UUID? = nil,
            weight: Double = 60,
            reps: Int = 8,
            setNumber: Int = 1,
            performedAt: Date = Date(timeIntervalSince1970: 1_000)
        ) -> WorkoutSetInput {
            WorkoutSetInput(
                userId: userId ?? user.id,
                workoutDayId: day.id,
                workoutDayExerciseId: dayExercise.id,
                weight: weight,
                reps: reps,
                setNumber: setNumber,
                performedAt: performedAt
            )
        }

        func otherDayInput() -> WorkoutSetInput {
            WorkoutSetInput(
                userId: user.id,
                workoutDayId: otherDay.id,
                workoutDayExerciseId: otherDayExercise.id,
                weight: 80,
                reps: 5,
                setNumber: 1,
                performedAt: Date(timeIntervalSince1970: 2_000)
            )
        }

        func persistedUser() throws -> UserEntity {
            let userId = user.id
            var descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate {
                    $0.id == userId
                }
            )
            descriptor.fetchLimit = 1

            return try #require(context.fetch(descriptor).first)
        }
    }
}
