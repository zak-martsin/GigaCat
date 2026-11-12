//
//  User.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//

import Foundation
import SwiftData

@Model
final class UserEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var selectedProgramId: UUID?
    var goal: TrainingGoal?
    var level: TrainingLevel?
    var avatarPath: String?
    var createdAt: Date
    var updatedAt: Date
    var revision: Int = 0

    init(
        id: UUID,
        selectedProgramId: UUID?,
        createdAt: Date,
        updatedAt: Date,
        revision: Int = 0,
        goal: TrainingGoal? = nil,
        level: TrainingLevel? = nil,
        avatarPath: String? = nil
    ) {
        self.id = id
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.goal = goal
        self.level = level
        self.avatarPath = avatarPath
    }
}
