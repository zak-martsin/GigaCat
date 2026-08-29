//
//  WorkoutDayExerciseEntity.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 05/08/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutDayExerciseEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var targetSets: Int?
    var targetReps: Int?
    var orderIndex: Int
    var isActive: Bool = true

    init(
        id: UUID,
        workoutDayId: UUID,
        exerciseId: UUID,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        orderIndex: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.workoutDayId = workoutDayId
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.orderIndex = orderIndex
        self.isActive = isActive
    }
}
