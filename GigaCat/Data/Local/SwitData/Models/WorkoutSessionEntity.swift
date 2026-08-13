//
//  WorkoutSession.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//
import Foundation
import SwiftData

@Model
final class WorkoutSessionEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var workoutDayId: UUID
    var statusRawValue: String
    var startedAt: Date
    var completedAt: Date?

    init(
        id: UUID,
        userId: UUID,
        workoutDayId: UUID,
        statusRawValue: String,
        startedAt: Date,
        completedAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.workoutDayId = workoutDayId
        self.statusRawValue = statusRawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
