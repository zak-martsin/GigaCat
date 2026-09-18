//
//  WorkoutDayEntity.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 05/08/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutDayEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var programId: UUID
    var title: String
    var orderIndex: Int
    var isActive: Bool = true

    init(
        id: UUID,
        programId: UUID,
        title: String,
        orderIndex: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.programId = programId
        self.title = title
        self.orderIndex = orderIndex
        self.isActive = isActive
    }
}
