//
//  ExerciseLog.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//
import Foundation
import SwiftData

@Model
final class ExerciseLogEntity: Identifiable {

    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var workoutDayExerciseId: UUID
    var weight: Double
    var reps: Int
    var setNumber: Int
    var performedAt: Date

    init(
        id: UUID,
        sessionId: UUID,
        workoutDayExerciseId: UUID,
        weight: Double,
        reps: Int,
        setNumber: Int,
        performedAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.workoutDayExerciseId = workoutDayExerciseId
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
        self.performedAt = performedAt
    }
}
