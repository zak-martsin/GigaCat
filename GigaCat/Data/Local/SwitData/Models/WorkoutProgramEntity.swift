//
//  WorkoutProgramEntity.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 04/08/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutProgramEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var authorId: UUID?
    var audience: WorkoutProgramAudience?
    var isActive: Bool = true
    var title: String
    var programDescription: String
    var tags: [WorkoutProgramTag]

    init(
        id: UUID,
        authorId: UUID? = nil,
        audience: WorkoutProgramAudience? = nil,
        isActive: Bool = true,
        title: String,
        description: String,
        tags: [WorkoutProgramTag]
    ) {
        self.id = id
        self.authorId = authorId
        self.audience = audience
        self.isActive = isActive
        self.title = title
        self.programDescription = description
        self.tags = tags
    }
}
