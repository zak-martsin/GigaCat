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
    var status: WorkoutSessionStatus
    var startedAt: Date
    var completedAt: Date?

    init(
        id: UUID,
        userId: UUID,
        workoutDayId: UUID,
        status: WorkoutSessionStatus,
        startedAt: Date,
        completedAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.workoutDayId = workoutDayId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
