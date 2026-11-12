import Foundation
import SwiftData
@testable import GigaCat

@MainActor
struct TrainingSessionFixture {
    let stack: SwiftDataStack
    let factory: LocalRepositoryFactory
    let user: User
    let day: WorkoutDay
    let assignments: [WorkoutDayExercise]

    init(storeURL: URL? = nil) throws {
        stack = try SwiftDataStack(isStoredInMemoryOnly: storeURL == nil, storeURL: storeURL)
        user = User(goal: .buildMuscle, level: .intermediate, avatarPath: "account/avatar.png")
        let program = try WorkoutProgram(title: "Targets", description: "Training fixture")
        day = try WorkoutDay(programId: program.id, title: "Day", orderIndex: 0)
        let exercise = try Exercise(name: "Bench", muscleGroup: .chest)
        let workoutDayID = day.id
        assignments = try [nil, 5, nil].enumerated().map { index, override in
            try WorkoutDayExercise(
                workoutDayId: workoutDayID, exerciseId: exercise.id, targetSets: override, orderIndex: index
            )
        }
        let context = stack.mainContext
        context.insert(UserMapper.toEntity(user))
        context.insert(WorkoutProgramMapper.toEntity(program))
        context.insert(WorkoutDayMapper.toEntity(day))
        context.insert(ExerciseMapper.toEntity(exercise))
        assignments.forEach { context.insert(WorkoutDayExerciseMapper.toEntity($0)) }
        try context.save()
        factory = LocalRepositoryFactory(stack: stack, currentUserIDProvider: CurrentUserContext(userID: user.id))
    }

    func start() async throws -> WorkoutSession {
        try await factory.workoutRepository.startSession(
            userId: user.id, workoutDayId: day.id, startedAt: Date(timeIntervalSince1970: 1000)
        )
    }

    func input(setNumber: Int = 1) -> WorkoutSetInput {
        WorkoutSetInput(
            userId: user.id, workoutDayId: day.id, workoutDayExerciseId: assignments[0].id,
            weight: 50, reps: 8, setNumber: setNumber, performedAt: Date(timeIntervalSince1970: 1100)
        )
    }
}
