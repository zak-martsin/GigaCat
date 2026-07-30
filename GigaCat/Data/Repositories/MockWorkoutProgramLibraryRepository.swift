import Foundation

/// In-memory program library repository used before production persistence is introduced.
struct MockWorkoutProgramLibraryRepository: WorkoutProgramLibraryRepository {
    private let store: MockDataStore

    init(store: MockDataStore) {
        self.store = store
    }

    func fetchSavedPrograms(for userId: UUID) async throws -> [WorkoutProgram] {
        try await store.savedPrograms(for: userId)
    }

    func isProgramSaved(_ programId: UUID, for userId: UUID) async throws -> Bool {
        try await store.isProgramSaved(programId, for: userId)
    }

    func saveProgram(_ programId: UUID, for userId: UUID) async throws {
        try await store.saveProgram(programId, for: userId)
    }

    func removeProgram(_ programId: UUID, for userId: UUID) async throws {
        try await store.removeProgram(programId, for: userId)
    }
}
