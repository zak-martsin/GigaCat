import Foundation

/// User-owned library membership for a program from the shared workout catalog.
struct SavedWorkoutProgram: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let programId: UUID
    let savedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        programId: UUID,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.savedAt = savedAt
    }
}
