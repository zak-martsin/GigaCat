import Foundation

/// Resolves recommendations before a session exists, through domain repository boundaries.
@MainActor
struct WorkoutRecommendationService {
    let userRepository: any UserRepository
    let programRepository: any WorkoutProgramRepository

    func recommendations(userID: UUID, workoutDayID: UUID) async throws -> [WorkoutExerciseTarget] {
        guard let user = try await userRepository.user(id: userID) else {
            throw RepositoryError.userNotFound
        }
        guard try await programRepository.fetchWorkoutDay(id: workoutDayID) != nil else {
            throw RepositoryError.workoutDayNotFound
        }
        let exercises = try await programRepository.fetchWorkoutDayExercises(workoutDayId: workoutDayID)
        return recommendations(exercises: exercises, user: user)
    }

    nonisolated func recommendations(exercises: [WorkoutDayExercise], user: User) -> [WorkoutExerciseTarget] {
        WorkoutTargetResolver().targets(exercises: exercises, user: user)
    }
}
