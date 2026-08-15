//
//  SavedWorkoutProgram.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 03/08/2026.
//
import Foundation
import SwiftData

@Model
final class SavedWorkoutProgramEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var programId: UUID
    var savedAt: Date

    init(
        id: UUID,
        userId: UUID,
        programId: UUID,
        savedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.savedAt = savedAt
    }
}
