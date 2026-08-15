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
    var appleUserId: String
    var selectedProgramId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        appleUserId: String,
        selectedProgramId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.selectedProgramId = selectedProgramId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
