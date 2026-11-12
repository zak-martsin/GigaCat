import Foundation

/// Provider-independent app profile whose ID matches the Supabase Auth account.
struct User: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let selectedProgramId: UUID?
    let goal: TrainingGoal?
    let level: TrainingLevel?
    let avatarPath: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        selectedProgramId: UUID? = nil,
        goal: TrainingGoal? = nil,
        level: TrainingLevel? = nil,
        avatarPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selectedProgramId = selectedProgramId
        self.goal = goal
        self.level = level
        self.avatarPath = avatarPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Changes training inputs while preserving account metadata, avatar and program selection.
    func updatingTraining(goal: TrainingGoal?, level: TrainingLevel?, at date: Date = Date()) -> User {
        User(
            id: id, selectedProgramId: selectedProgramId,
            goal: goal, level: level, avatarPath: avatarPath,
            createdAt: createdAt, updatedAt: date
        )
    }

    /// Returns a new user value with an updated selected workout program.
    func selectingProgram(_ programId: UUID?, updatedAt: Date = Date()) -> User {
        User(
            id: id,
            selectedProgramId: programId,
            goal: goal,
            level: level,
            avatarPath: avatarPath,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
