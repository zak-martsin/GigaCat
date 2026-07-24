import Foundation
import Testing
@testable import GigaCat

struct WorkoutContextServiceTests {

    @Test
    func activeSessionOverridesSelectedProgramAndOpensItsDay() async throws {
        let fixture = try Fixture(
            selection: .secondProgram,
            sessionState: .activeFirstProgramSecondDay
        )

        let context = try await fixture.service.loadContext()

        #expect(context.program.id == fixture.firstProgram.id)
        #expect(context.initialDayID == fixture.firstProgramDays[1].id)
        #expect(context.activeSession?.workoutDayId == fixture.firstProgramDays[1].id)
    }

    @Test
    func selectedProgramContinuesAfterItsLastCompletedDay() async throws {
        let fixture = try Fixture(
            selection: .firstProgram,
            sessionState: .completedFirstProgramFirstDay
        )

        let context = try await fixture.service.loadContext()

        #expect(context.program.id == fixture.firstProgram.id)
        #expect(context.initialDayID == fixture.firstProgramDays[1].id)
        #expect(context.activeSession == nil)
    }

    @Test
    func newlySelectedProgramStartsFromItsFirstDay() async throws {
        let fixture = try Fixture(
            selection: .secondProgram,
            sessionState: .completedFirstProgramFirstDay
        )

        let context = try await fixture.service.loadContext()

        #expect(context.program.id == fixture.secondProgram.id)
        #expect(context.initialDayID == fixture.secondProgramDays[0].id)
    }

    @Test
    func missingSelectionContinuesTheLastUsedProgram() async throws {
        let fixture = try Fixture(
            selection: .none,
            sessionState: .completedFirstProgramFirstDay
        )

        let context = try await fixture.service.loadContext()

        #expect(context.program.id == fixture.firstProgram.id)
        #expect(context.initialDayID == fixture.firstProgramDays[1].id)
    }

    @Test
    func missingSelectionAndHistoryUseFirstRecommendedProgram() async throws {
        let fixture = try Fixture(selection: .none, sessionState: .none)

        let context = try await fixture.service.loadContext()

        #expect(context.program.id == fixture.secondProgram.id)
        #expect(context.initialDayID == fixture.secondProgramDays[0].id)
    }

    @Test
    func contextContainsDaysWithTheirExerciseDefinitionsAndTargets() async throws {
        let fixture = try Fixture(selection: .firstProgram, sessionState: .none)

        let context = try await fixture.service.loadContext()

        #expect(context.dayContents.map(\.day) == fixture.firstProgramDays)
        #expect(
            context.dayContents[0].exercises == [
                WorkoutExerciseContent(
                    dayExercise: fixture.firstDayExercise,
                    exercise: fixture.firstExercise
                )
            ]
        )
        #expect(context.dayContents[1].exercises.isEmpty)
    }
}

private extension WorkoutContextServiceTests {
    enum Selection {
        case firstProgram
        case secondProgram
        case none
    }

    enum SessionState {
        case activeFirstProgramSecondDay
        case completedFirstProgramFirstDay
        case none
    }

    struct Identifiers {
        let userID = UUID()
        let firstProgramID = UUID()
        let secondProgramID = UUID()
        let firstProgramDayIDs = [UUID(), UUID()]
        let secondProgramDayIDs = [UUID(), UUID()]
        let firstDayExerciseID = UUID()
        let firstExerciseID = UUID()
    }

    struct Fixture {
        let firstProgram: WorkoutProgram
        let secondProgram: WorkoutProgram
        let firstProgramDays: [WorkoutDay]
        let secondProgramDays: [WorkoutDay]
        let firstDayExercise: WorkoutDayExercise
        let firstExercise: Exercise
        let service: WorkoutContextService

        init(selection: Selection, sessionState: SessionState) throws {
            let identifiers = Identifiers()
            let now = Date(timeIntervalSince1970: 10_000)
            let programs = try Self.makePrograms(identifiers: identifiers)
            let days = try Self.makeDays(identifiers: identifiers)
            let exerciseContent = try Self.makeExerciseContent(identifiers: identifiers)
            let user = try Self.makeUser(selection: selection, identifiers: identifiers, now: now)
            let sessions = try Self.makeSessions(
                state: sessionState,
                identifiers: identifiers,
                now: now
            )

            firstProgram = programs.first
            secondProgram = programs.second
            firstProgramDays = days.firstProgram
            secondProgramDays = days.secondProgram
            firstDayExercise = exerciseContent.dayExercise
            firstExercise = exerciseContent.exercise

            let store = MockDataStore(
                users: [user],
                programs: [firstProgram, secondProgram],
                programCatalogMetadataByProgramID: [
                    identifiers.firstProgramID: ProgramCatalogMetadata(isRecommended: false),
                    identifiers.secondProgramID: ProgramCatalogMetadata(isRecommended: true)
                ],
                workoutDays: firstProgramDays + secondProgramDays,
                dayExercises: [firstDayExercise],
                exercises: [firstExercise],
                sessions: sessions,
                currentUserID: identifiers.userID
            )
            let factory = MockRepositoryFactory(store: store)
            service = WorkoutContextService(
                userRepository: factory.userRepository,
                programCatalogRepository: factory.programCatalogRepository,
                workoutProgramRepository: factory.workoutProgramRepository,
                workoutRepository: factory.workoutRepository
            )
        }

        private static func makePrograms(
            identifiers: Identifiers
        ) throws -> (first: WorkoutProgram, second: WorkoutProgram) {
            let first = try WorkoutProgram(
                id: identifiers.firstProgramID,
                title: "Alpha Program",
                description: "The previously used program."
            )
            let second = try WorkoutProgram(
                id: identifiers.secondProgramID,
                title: "Beta Recommended",
                description: "The recommended fallback program."
            )
            return (first, second)
        }

        private static func makeDays(
            identifiers: Identifiers
        ) throws -> (firstProgram: [WorkoutDay], secondProgram: [WorkoutDay]) {
            let firstProgramDays = try makeDays(
                ids: identifiers.firstProgramDayIDs,
                programID: identifiers.firstProgramID,
                titlePrefix: "Alpha"
            )
            let secondProgramDays = try makeDays(
                ids: identifiers.secondProgramDayIDs,
                programID: identifiers.secondProgramID,
                titlePrefix: "Beta"
            )
            return (firstProgramDays, secondProgramDays)
        }

        private static func makeDays(
            ids: [UUID],
            programID: UUID,
            titlePrefix: String
        ) throws -> [WorkoutDay] {
            try ids.enumerated().map { index, id in
                try WorkoutDay(
                    id: id,
                    programId: programID,
                    title: "\(titlePrefix) Day \(index + 1)",
                    orderIndex: index
                )
            }
        }

        private static func makeExerciseContent(
            identifiers: Identifiers
        ) throws -> (dayExercise: WorkoutDayExercise, exercise: Exercise) {
            let exercise = try Exercise(
                id: identifiers.firstExerciseID,
                name: "Bench Press",
                muscleGroup: .chest
            )
            let dayExercise = try WorkoutDayExercise(
                id: identifiers.firstDayExerciseID,
                workoutDayId: identifiers.firstProgramDayIDs[0],
                exerciseId: exercise.id,
                targetSets: 3,
                targetReps: 8,
                orderIndex: 0
            )
            return (dayExercise, exercise)
        }

        private static func makeUser(
            selection: Selection,
            identifiers: Identifiers,
            now: Date
        ) throws -> User {
            let selectedProgramID: UUID? = switch selection {
            case .firstProgram:
                identifiers.firstProgramID
            case .secondProgram:
                identifiers.secondProgramID
            case .none:
                nil
            }

            return try User(
                id: identifiers.userID,
                appleUserId: "workout-context-user",
                selectedProgramId: selectedProgramID,
                createdAt: now.addingTimeInterval(-1_000),
                updatedAt: now
            )
        }

        private static func makeSessions(
            state: SessionState,
            identifiers: Identifiers,
            now: Date
        ) throws -> [WorkoutSession] {
            switch state {
            case .activeFirstProgramSecondDay:
                return [
                    try WorkoutSession(
                        userId: identifiers.userID,
                        workoutDayId: identifiers.firstProgramDayIDs[1],
                        startedAt: now
                    )
                ]
            case .completedFirstProgramFirstDay:
                return [
                    try WorkoutSession(
                        userId: identifiers.userID,
                        workoutDayId: identifiers.firstProgramDayIDs[0],
                        status: .completed,
                        startedAt: now.addingTimeInterval(-600),
                        completedAt: now
                    )
                ]
            case .none:
                return []
            }
        }
    }
}
