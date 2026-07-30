import Foundation

/// Domain-facing access to the workout programs a user has explicitly saved.
protocol WorkoutProgramLibraryRepository: Sendable {
    func fetchSavedPrograms(for userId: UUID) async throws -> [WorkoutProgram]
    func isProgramSaved(_ programId: UUID, for userId: UUID) async throws -> Bool
    func saveProgram(_ programId: UUID, for userId: UUID) async throws
    func removeProgram(_ programId: UUID, for userId: UUID) async throws
}
