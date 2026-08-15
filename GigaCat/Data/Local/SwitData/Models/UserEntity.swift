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

    init(
        id: UUID,
        selectedProgramId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
