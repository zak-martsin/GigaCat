import Foundation

/// Clears a current selection that no longer points to an active local catalog program.
@MainActor
struct SelectedProgramReconciliationService {
    private let userRepository: any UserRepository
    private let workoutProgramRepository: any WorkoutProgramRepository

    init(
        userRepository: any UserRepository,
        workoutProgramRepository: any WorkoutProgramRepository
    ) {
        self.userRepository = userRepository
        self.workoutProgramRepository = workoutProgramRepository
    }

    func clearUnavailableSelection(for userID: UUID) async throws -> Bool {
        guard let user = try await userRepository.user(id: userID),
              let selectedProgramID = user.selectedProgramId else {
            return false
        }

        let selectedProgram: WorkoutProgram?
        do {
            selectedProgram = try await workoutProgramRepository.fetchProgram(
                id: selectedProgramID
            )
        } catch RepositoryError.workoutProgramNotFound {
            selectedProgram = nil
        }

        guard selectedProgram?.isActive == true else {
            _ = try await userRepository.updateSelectedProgram(
                for: userID,
                programId: nil
            )
            return true
        }

        return false
    }
}
