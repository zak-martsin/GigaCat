//
//  ExerciseEntity.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 05/08/2026.
//

import Foundation
import SwiftData

@Model
final class ExerciseEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: ExerciseMuscleGroup

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: ExerciseMuscleGroup
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
