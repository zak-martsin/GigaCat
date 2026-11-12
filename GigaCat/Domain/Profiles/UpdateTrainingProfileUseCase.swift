import Foundation

/// Entry point for local training preference changes; the repository owns the atomic write boundary.
@MainActor
struct UpdateTrainingProfileUseCase {
    let userRepository: any UserRepository

    func execute(userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) async throws -> User {
        try await userRepository.updateTrainingPreferences(for: userID, goal: goal, level: level)
    }
}
