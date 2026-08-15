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
    var title: String
    var programDescription: String
    var tags: [WorkoutProgramTag]

    init(
        id: UUID,
        title: String,
        description: String,
        tags: [WorkoutProgramTag]
    ) {
        self.id = id
        self.title = title
        self.programDescription = description
        self.tags = tags
    }
}
