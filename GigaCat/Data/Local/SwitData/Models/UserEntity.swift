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
    var createdAt: Date
    var updatedAt: Date
    var revision: Int = 0

    init(
        id: UUID,
        selectedProgramId: UUID?,
        createdAt: Date,
        updatedAt: Date,
        revision: Int = 0
    ) {
        self.id = id
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
    }
}
