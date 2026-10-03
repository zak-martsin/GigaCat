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
    var artworkPath: String?
    var artworkRevision: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: ExerciseMuscleGroup,
        artworkPath: String? = nil,
        artworkRevision: Int = 0
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.artworkPath = artworkPath
        self.artworkRevision = artworkRevision
    }
}
